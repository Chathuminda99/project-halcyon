#!/usr/bin/env bash
# Build the three Packer base images and register them as Vagrant boxes.
# Run once (or whenever you want to refresh base images). Requires:
#   - Windows Server 2022 eval ISO + Windows 11 eval ISO downloaded locally
#   - HALCYON_WIN2022_ISO / HALCYON_WIN11_ISO env vars pointing at them
#   - Real iso_checksum values set in each packer/*/*.pkr.hcl (see packer/README.md)
#
# On Windows: run from WSL2 - `packer` and `vagrant` resolve to their
# Windows-native .exe via WSL interop (both must run on the same OS as
# VMware Workstation). No Ansible is involved in this script.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${HALCYON_WIN2022_ISO:?set to the path of your Windows Server 2022 eval ISO}"
: "${HALCYON_WIN11_ISO:?set to the path of your Windows 11 eval ISO}"

packer init packer/win2022
packer init packer/win11
packer init packer/ubuntu2204

echo "[build-images] building win2022 (this takes ~45-90 min unattended)..."
packer build -var "iso_url=${HALCYON_WIN2022_ISO}" packer/win2022/win2022.pkr.hcl

echo "[build-images] building win11..."
packer build -var "iso_url=${HALCYON_WIN11_ISO}" packer/win11/win11.pkr.hcl

echo "[build-images] building ubuntu2204..."
packer build packer/ubuntu2204/ubuntu2204.pkr.hcl

echo "[build-images] registering Vagrant boxes..."
vagrant box add halcyon/win2022  packer/win2022/halcyon-win2022.box       --force
vagrant box add halcyon/win11    packer/win11/halcyon-win11.box           --force
vagrant box add halcyon/ubuntu22 packer/ubuntu2204/halcyon-ubuntu2204.box --force

echo "[build-images] done. 'vagrant box list' should now show halcyon/win2022,"
echo "halcyon/win11, halcyon/ubuntu22."
echo
echo "[build-images] Kali (ATTACK) is not built via Packer - download the"
echo "pre-built VMware image from kali.org/get-kali, import it into Workstation,"
echo "then either 'vagrant box add kalilinux/rolling <exported .box>' or point"
echo "the Vagrantfile's 'attack' entry at your imported .vmx directly."
