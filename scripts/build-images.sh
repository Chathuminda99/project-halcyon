#!/usr/bin/env bash
# Build the three Packer base images and register them as Vagrant boxes.
# Run once (or whenever you want to refresh base images). Requires:
#   - Windows Server 2022 eval ISO + Windows 11 eval ISO downloaded locally
#   - HALCYON_WIN2022_ISO / HALCYON_WIN11_ISO env vars pointing at them
#   - packer plugin install (first run only)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${HALCYON_WIN2022_ISO:?set to the path of your Windows Server 2022 eval ISO}"
: "${HALCYON_WIN11_ISO:?set to the path of your Windows 11 eval ISO}"

packer init packer/win2022
packer init packer/win11
packer init packer/ubuntu2204

echo "[build-images] building win2022..."
packer build -var "iso_url=${HALCYON_WIN2022_ISO}" packer/win2022/win2022.pkr.hcl

echo "[build-images] building win11..."
packer build -var "iso_url=${HALCYON_WIN11_ISO}" packer/win11/win11.pkr.hcl

echo "[build-images] building ubuntu2204..."
packer build packer/ubuntu2204/ubuntu2204.pkr.hcl

echo "[build-images] converting Packer output -> Vagrant boxes..."
for name in win2022 win11 ubuntu22; do
  src="packer/${name/ubuntu22/ubuntu2204}/output-*/*.vmx"
  echo "  (add box 'halcyon/${name}' from the vmware-iso output manually with"
  echo "   'vagrant package --base <vmname>' if the vmware-vagrant post-processor"
  echo "   isn't configured - see packer/README.md)"
done

echo "[build-images] done. Get Kali separately (pre-built VMware image from"
echo "kali.org/get-kali) and register it as the 'kalilinux/rolling' Vagrant box,"
echo "or point Vagrantfile's ATTACK entry at your own imported .vmx."
