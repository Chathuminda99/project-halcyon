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

- VMware Workstation Pro 17.5.2+ (free for personal/commercial use, no license key)
- Vagrant + `vagrant-vmware-desktop` plugin + Vagrant VMware Utility
- Packer (to build the base images once)
- Ansible (control node — can run from WSL/Linux/macOS; Windows targets are managed
  over WinRM, Linux targets over SSH)
- Windows Server 2022 and Windows 11 evaluation ISOs (Microsoft eval, 180-day)
- Host: ≥32 GB RAM, ≥250 GB free SSD, network access disabled to any real/production LAN

## Quick start

```
scripts/build-images.sh      # Packer: build the 3 base VM images (one-time, ~1-2h)
scripts/deploy.sh            # Vagrant up + full Ansible provisioning + randomize + snapshot
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
