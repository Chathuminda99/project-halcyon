#!/usr/bin/env bash
# Project Halcyon — full deploy: randomize secrets/paths, then vagrant up
# (which triggers per-host Ansible provisioning), then snapshot every VM as
# the "clean, freshly-armed" state that scripts/reset.sh reverts to.
set -euo pipefail
cd "$(dirname "$0")/.."

SEED="${HALCYON_SEED:-}"

echo "[deploy] generating per-deploy secrets and live vulnerability paths..."
if [ -n "$SEED" ]; then
  python3 ansible/roles/randomize/files/gen_seed.py --seed "$SEED"
else
  python3 ansible/roles/randomize/files/gen_seed.py
fi

echo "[deploy] booting and provisioning all VMs (this can take 30-90 minutes)..."
vagrant up

echo "[deploy] snapshotting all VMs as clean-armed baseline..."
for vm in dc01 srv01 ws01 ws02 web01 attack; do
  vagrant snapshot save "$vm" clean-armed || \
    echo "[deploy] WARNING: could not snapshot $vm automatically - snapshot it manually (vagrant snapshot save $vm clean-armed)"
done

echo "[deploy] done. Answer key: docs/answer-key.md (do not distribute to students)."
echo "[deploy] student brief: docs/student-brief.md"
