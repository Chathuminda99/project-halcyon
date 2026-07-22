#!/usr/bin/env bash
# Sanity-check that every host and service in the lab is up and reachable.
# Run from a machine on the same host-only vmnet (from ATTACK, or from WSL2
# on the Windows Workstation host - WSL2 can normally reach 10.20.10.0/24
# through the Windows host's route to the VMware host-only adapter).
set -uo pipefail
cd "$(dirname "$0")/.."

PASS=0
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  OK    $desc"
    PASS=$((PASS+1))
  else
    echo "  FAIL  $desc"
    FAIL=$((FAIL+1))
  fi
}

echo "== Network reachability =="
check "DC01 (10.20.10.10) ping"   ping -c1 -W2 10.20.10.10
check "SRV01 (10.20.10.20) ping"  ping -c1 -W2 10.20.10.20
check "WS01 (10.20.10.31) ping"   ping -c1 -W2 10.20.10.31
check "WS02 (10.20.10.32) ping"   ping -c1 -W2 10.20.10.32
check "WEB01 (10.20.10.40) ping"  ping -c1 -W2 10.20.10.40

echo "== Core services =="
check "DC01 LDAP (389)"       bash -c "echo > /dev/tcp/10.20.10.10/389"
check "DC01 Kerberos (88)"    bash -c "echo > /dev/tcp/10.20.10.10/88"
check "DC01 CA web enroll (80)" curl -sf http://10.20.10.10/certsrv/
check "SRV01 MSSQL (1433)"    bash -c "echo > /dev/tcp/10.20.10.20/1433"
check "WEB01 app /healthz"    curl -sf http://10.20.10.40/healthz

echo
echo "== Result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ]
