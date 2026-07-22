#!/usr/bin/env bash
# Project Halcyon — full deploy: randomize secrets/paths, boot all VMs
# (Vagrant/VMware Workstation), wait for them to come up, then provision
# with Ansible, then snapshot every VM as the "clean, freshly-armed" state
# that scripts/reset.sh reverts to.
#
# On a Windows host: run this script from a WSL2 (Ubuntu) terminal, not
# PowerShell/cmd. `vagrant` here resolves to the Windows-native vagrant.exe
# via WSL interop (it drives VMware Workstation on the Windows side, which
# is where it must run); `ansible-playbook` resolves to the ansible-core
# install inside WSL2 (Ansible has no supported Windows control node, which
# is also why the Vagrantfile has no built-in ansible provisioner - see its
# header comment). The only requirement linking the two: WSL2 must be able
# to reach the lab's host-only subnet (10.20.10.0/24) over the network -
# this normally works automatically since WSL2 NATs outbound traffic through
# the Windows host, which already has a route to that subnet via the VMware
# host-only adapter. Verify with `ping 10.20.10.10` after `vagrant up` if
# the Ansible step below can't connect.
set -euo pipefail
cd "$(dirname "$0")/.."

SEED="${HALCYON_SEED:-}"

echo "[deploy] generating per-deploy secrets and live vulnerability paths..."
if [ -n "$SEED" ]; then
  python3 ansible/roles/randomize/files/gen_seed.py --seed "$SEED"
else
  python3 ansible/roles/randomize/files/gen_seed.py
fi

echo "[deploy] booting all VMs (VMware Workstation, via vagrant)..."
vagrant up

echo "[deploy] provisioning with Ansible (this can take 30-90 minutes)..."
ansible-playbook -i ansible/inventory.yml ansible/site.yml

echo "[deploy] snapshotting all VMs as clean-armed baseline..."
for vm in dc01 srv01 ws01 ws02 web01 attack; do
  vagrant snapshot save "$vm" clean-armed || \
    echo "[deploy] WARNING: could not snapshot $vm automatically - snapshot it manually (vagrant snapshot save $vm clean-armed)"
done

echo "[deploy] done. Answer key: docs/answer-key.md (do not distribute to students)."
echo "[deploy] student brief: docs/student-brief.md"
