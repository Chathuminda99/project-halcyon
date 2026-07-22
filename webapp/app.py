"""
Halcyon Logistics — internal shipment tracking intranet.

This is a deliberately built training application (Project Halcyon). It is NOT
a copy of any public vulnerable-app project. Every vulnerability below is a
configuration/logic-class bug (OWASP-style), not a dependency CVE:

  - Broken access control / IDOR on shipment detail lookup
  - SSRF in the "import manifest from URL" feature (reachable due to the BAC bug)
  - Unrestricted file upload on the proof-of-delivery photo endpoint
  - SQL injection in the shipment search (raw string query building)
  - A stored AD service-account credential, readable via the SQLi

Which of these are reachable in a given deployment is controlled by the
HALCYON_LIVE_PATHS environment variable (space-separated path IDs), set by
ansible/roles/web_app from the per-deploy randomized selection.
"""
import os
import re
import subprocess
import uuid
from functools import wraps

import psycopg2
import psycopg2.extras
import requests
from flask import (Flask, abort, g, redirect, render_template, request,
                    send_from_directory, session, url_for)
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.secret_key = os.environ.get("HALCYON_FLASK_SECRET", "dev-secret-change-me")

UPLOAD_DIR = "/var/www/intranet/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

LIVE_PATHS = set(os.environ.get("HALCYON_LIVE_PATHS", "").split())

DB_DSN = os.environ.get("HALCYON_DB_DSN", "dbname=halcyon user=halcyon password=halcyon host=localhost")


def get_db():
    if "db" not in g:
        g.db = psycopg2.connect(DB_DSN)
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login"))
        return view(*args, **kwargs)
    return wrapped


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        db = get_db()
        cur = db.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute(
            "SELECT id, username, password, role, ops_team FROM users WHERE username = %s",
            (username,),
        )
        user = cur.fetchone()
        if user and user["password"] == password:  # plaintext compare - intentional weak auth store
            session["user_id"] = user["id"]
            session["username"] = user["username"]
            session["role"] = user["role"]
            session["ops_team"] = user["ops_team"]
            return redirect(url_for("dashboard"))
        return render_template("login.html", error="Invalid credentials")
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/")
def index():
    return redirect(url_for("dashboard") if "user_id" in session else url_for("login"))


@app.route("/dashboard")
@login_required
def dashboard():
    return render_template("dashboard.html", username=session.get("username"))


# ---------------------------------------------------------------------------
# VULN 1 (always live): Broken Access Control / IDOR on shipment detail.
# Any logged-in user can view any shipment by ID regardless of ops_team,
# including ones flagged internal_notes containing operational secrets.
# There is no ownership check here at all — that's the bug.
# ---------------------------------------------------------------------------
@app.route("/shipment/<int:shipment_id>")
@login_required
def shipment_detail(shipment_id):
    db = get_db()
    cur = db.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM shipments WHERE id = %s", (shipment_id,))
    shipment = cur.fetchone()
    if not shipment:
        abort(404)
    # BUG: no check that session["ops_team"] == shipment["ops_team"]
    return render_template("shipment.html", shipment=shipment)


# ---------------------------------------------------------------------------
# VULN 2: SSRF in "import manifest from URL". Intended only for the Ops-Admin
# role, but because shipment_detail has no access check, any authenticated
# user reaches manifests belonging to ops-admin-owned shipments and can see
# this feature is exposed the same way — the *server-side* route itself also
# fails to re-check role, trusting a client-side "is_admin" hidden field.
# ---------------------------------------------------------------------------
@app.route("/shipment/<int:shipment_id>/import-manifest", methods=["POST"])
@login_required
def import_manifest(shipment_id):
    # BUG: role check trusts a client-controlled form field instead of session["role"]
    is_admin_claim = request.form.get("client_is_admin") == "true"
    if not is_admin_claim:
        abort(403)

    manifest_url = request.form.get("manifest_url", "")
    if not manifest_url:
        return {"error": "manifest_url required"}, 400

    if "web_idor_ssrf_upload" not in LIVE_PATHS:
        # this deployment's variant enforces a strict allowlist here instead
        allowed_hosts = {"cdn.halcyon.local"}
        from urllib.parse import urlparse
        if urlparse(manifest_url).hostname not in allowed_hosts:
            abort(403)

    # BUG (when live): no allowlist/denylist on scheme or destination host ->
    # classic SSRF. The app server can reach internal-only management
    # surfaces (e.g. ADCS web enrollment on DC01) that the outside world can't.
    try:
        resp = requests.get(manifest_url, timeout=5)
        content = resp.text[:5000]
    except requests.RequestException as exc:
        content = f"fetch error: {exc}"

    return render_template("manifest_result.html", content=content, url=manifest_url)


# ---------------------------------------------------------------------------
# VULN 3: Unrestricted file upload for proof-of-delivery photos.
# Only a client-side accept=".jpg,.png" hint; server does no content-type or
# extension enforcement, and serves the upload directory directly.
# ---------------------------------------------------------------------------
@app.route("/shipment/<int:shipment_id>/upload-pod", methods=["POST"])
@login_required
def upload_pod(shipment_id):
    file = request.files.get("photo")
    if not file or file.filename == "":
        return {"error": "no file"}, 400

    # BUG: secure_filename is applied to the name but extension/content is
    # never validated, and the directory is directly web-served.
    filename = f"{uuid.uuid4().hex}_{secure_filename(file.filename)}"
    path = os.path.join(UPLOAD_DIR, filename)
    file.save(path)

    return {"stored_as": filename, "url": url_for("uploaded_file", filename=filename)}


@app.route("/uploads/<path:filename>")
def uploaded_file(filename):
    return send_from_directory(UPLOAD_DIR, filename)


# ---------------------------------------------------------------------------
# VULN 4: SQL injection in shipment search — raw string formatting instead of
# a parameterized query. The `integrations` table (joined via UNION) holds a
# cached AD service-account credential used by a legacy sync job.
# ---------------------------------------------------------------------------
@app.route("/search")
@login_required
def search():
    q = request.args.get("q", "")
    db = get_db()
    cur = db.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    if "web_sqli_creds_leak" in LIVE_PATHS:
        # BUG: string-built query, no parameter binding.
        query = f"SELECT id, reference, destination, status FROM shipments WHERE reference ILIKE '%{q}%'"
        try:
            cur.execute(query)
            results = cur.fetchall()
        except psycopg2.Error as exc:
            db.rollback()
            return render_template("search.html", results=[], q=q, error=str(exc))
    else:
        cur.execute(
            "SELECT id, reference, destination, status FROM shipments WHERE reference ILIKE %s",
            (f"%{q}%",),
        )
        results = cur.fetchall()

    return render_template("search.html", results=results, q=q)


# ---------------------------------------------------------------------------
# Health check (used by scripts/health.sh) — intentionally unauthenticated.
# ---------------------------------------------------------------------------
@app.route("/healthz")
def healthz():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
