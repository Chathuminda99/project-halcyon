# Project Halcyon — Custom AD + Web Pentest Range

A self-hosted, deliberately vulnerable practice range for Active Directory and web
application penetration testing, built for local **VMware Workstation** deployment.

This is **not** a fork of GOAD (Game of Active Directory) or any public lab. It uses an
original topology, naming scheme, and web application, and randomizes secrets and which
vulnerability paths are active on every deploy — see `docs/architecture.md` for why.

## What's inside

- `corp.halcyon.local` — single-forest AD domain: a DC (with AD CS), an MSSQL server,
  two Windows clients, and a domain-joined Linux web server (Ubuntu, SSSD).
- A hand-written vulnerable intranet web app (Flask) as the only external entry point.
- Non-CVE, configuration-class vulnerabilities only: OWASP-style web bugs, Kerberos
  misconfigs, ACL abuse, ADCS ESC1/ESC4/ESC6/ESC8, delegation/RBCD, NTLM relay,
  MSSQL misconfig, endpoint credential exposure.
- Windows Defender AV **on** throughout — this is not an AV-off lab.

## Requirements

- VMware Workstation Pro 17.5.2+ (free for personal/commercial use, no license key) —
  available for both Windows and Linux
- Vagrant + `vagrant-vmware-desktop` plugin + Vagrant VMware Utility
- Packer (to build the base images once)
- Ansible (control node — see "Windows host" below if that's you; native on Linux)
- Windows Server 2022 and Windows 11 evaluation ISOs (Microsoft eval, 180-day)
- Host: ≥32 GB RAM, ≥250 GB free SSD, network access disabled to any real/production LAN

## Host OS: Linux vs. Windows

Both are supported — `vagrant-vmware-desktop` is HashiCorp's official plugin
for VMware Workstation on either OS. Which path applies to you depends on
where VMware Workstation itself is installed.

### Linux host (simpler — everything native, no extra layer)

Install VMware Workstation Pro, Vagrant (+ `vagrant-vmware-desktop` plugin +
Vagrant VMware Utility), Packer, and Ansible directly on the Linux host:
```
pip3 install -r requirements-control.txt
ansible-galaxy collection install -r ansible/requirements.yml
```
Then just run `scripts/*.sh` from that same shell — no WSL, no interop, no
extra reachability checks. One caveat worth knowing before you're deep into
a build: there are scattered community reports of `vagrant-vmware-desktop`
hitting `vmrun`-related errors on some Linux setups (permissions on
`/dev/vmmon`/`/dev/vmnet*`, or the Vagrant VMware Utility service not
running). If `vagrant up` fails oddly, check the Vagrant VMware Utility's
own service/logs before assuming it's this repo's config.

### Windows host

VMware Workstation (and therefore Vagrant/Packer, which drive it) only run on
Windows here. Ansible has no supported Windows control node, so it runs from
**WSL2** instead, as a step decoupled from Vagrant's own provisioner — the
Vagrantfile intentionally has no built-in `ansible` provisioner block (see
its header comment for why that specific combination doesn't work).

Setup, once:
1. Install VMware Workstation Pro, Vagrant, and Packer **natively on
   Windows** (PowerShell/installer, not inside WSL2). Install the
   `vagrant-vmware-desktop` plugin and the Vagrant VMware Utility per
   HashiCorp's docs.
2. Install **WSL2** with an Ubuntu distro: `wsl --install`.
3. Inside that WSL2 Ubuntu shell, install Ansible + Python deps:
   ```
   sudo apt update && sudo apt install -y python3-pip git
   pip3 install -r requirements-control.txt
   ansible-galaxy collection install -r ansible/requirements.yml
   ```
4. Do all lab work — `scripts/*.sh`, `vagrant`, `packer` — from that **same
   WSL2 terminal**. `vagrant`/`packer` resolve to their Windows `.exe` via
   WSL interop automatically (so they still drive VMware Workstation on the
   Windows side); `ansible-playbook` resolves to the WSL2-native install.
5. Clone the repo inside the WSL2 filesystem (e.g. `~/project-halcyon`), not
   under `/mnt/c/...` — much faster I/O and avoids Windows/Linux path
   translation issues with Vagrant.

One thing to verify once, not assume: WSL2 needs to reach the lab's
host-only subnet (`10.20.10.0/24`) over the network for the Ansible step to
connect. This normally works automatically — WSL2 NATs outbound traffic
through the Windows host, which already has a route to that subnet via the
VMware host-only adapter — but confirm with `ping 10.20.10.10` from WSL2
after `vagrant up` before assuming the Ansible step will work.

## Quick start

On Linux, run this directly. On Windows, run it from the WSL2 terminal
described above.

```
scripts/build-images.sh      # Packer: build the 3 base VM images (one-time, ~1-2h)
scripts/deploy.sh            # vagrant up, then Ansible provisioning + randomize + snapshot
scripts/health.sh            # verify every host/service is reachable and correctly configured
scripts/reset.sh             # revert all VMs to the clean, freshly-armed snapshot
```

See `docs/student-brief.md` for the in-lab starting point (what a tester is told) and
`docs/architecture.md` for the full design rationale, topology, and vulnerability map.
The answer key is generated per-deploy at `docs/answer-key.md` (gitignored — it contains
the randomized secrets and solution paths for this specific deployment).

## Isolation

This lab runs on an isolated VMware **host-only** network only. Do not bridge any VM to
your real LAN or the internet. Hosts run intentionally weakened configurations, eval
Windows licenses, and default/weak credentials — treat the whole subnet as hostile.
