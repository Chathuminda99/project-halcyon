# Base image build notes

Manual steps required before `scripts/build-images.sh` will work end-to-end
(these involve licensed/large media that can't be scripted or fetched here):

1. **Windows Server 2022 evaluation ISO** — download from the Microsoft
   Evaluation Center, set `HALCYON_WIN2022_ISO=/path/to/iso`.
2. **Windows 11 evaluation ISO** — same source, set `HALCYON_WIN11_ISO=...`.
   Enterprise eval works too; update `packer/win11/autounattend.xml`'s
   `ProductKey` block if you need a specific SKU selected from an ISO with
   multiple editions.
3. **Checksums** — fill in the real `sha256:...` for each ISO in
   `packer/*/*.pkr.hcl` (`iso_checksum` variable). Left as `"none"` by
   default, which Packer accepts but does not recommend.
4. **Ubuntu 22.04** — `packer/ubuntu2204/ubuntu2204.pkr.hcl` points at the
   official releases.ubuntu.com ISO and downloads it automatically; still
   pin the checksum from the published SHA256SUMS file.
5. **Ubuntu autoinstall password** — `packer/ubuntu2204/http/user-data` ships
   a placeholder bcrypt/sha512 hash for the `vagrant` user. Regenerate with
   `mkpasswd -m sha-512` (from `whois` package) before building.
6. **Vagrant box packaging** — after each Packer build completes, the output
   is a raw VMware VM directory, not yet a `.box`. Package it:
   ```
   vagrant package --base <vm-name-from-packer-output> --output halcyon-win2022.box
   vagrant box add halcyon/win2022 halcyon-win2022.box
   ```
   Repeat for `win11` -> `halcyon/win11` and `ubuntu2204` -> `halcyon/ubuntu22`.
7. **Kali (ATTACK)** — not built via Packer; download the pre-built VMware
   image from kali.org/get-kali, import into Workstation, then either
   `vagrant box add kalilinux/rolling <exported .box>` or point the
   `Vagrantfile`'s `attack` entry at the imported `.vmx` directly.

None of the produced images should ever have a network adapter bridged to a
real LAN — the Vagrantfile only wires them to the isolated host-only vmnet.
