# Halcyon Logistics — Engagement Brief

You have been engaged to perform an internal penetration test against Halcyon
Logistics' corporate network. Scope, rules, and starting information below.

## Scope

- The entire `10.20.10.0/24` network is in scope.
- Your attack box is on the same flat network. There is no firewall between
  hosts — this is a deliberate simplification of the lab, not something to
  rely on in a real engagement.
- Windows Defender is running on all Windows hosts. It is not disabled for
  you. Plan accordingly.

## Starting point

You have been given network access only — no credentials, no internal
documentation. The one thing you were told: Halcyon runs an internal
operations intranet reachable at `http://intranet.halcyon.local` (add it to
your `/etc/hosts` pointed at the web server's IP, or resolve it from the
lab's DNS once you locate it).

## Objectives

Work toward increasing levels of access. Each milestone below has a proof
token to submit:

1. **Web foothold** — achieve code execution on the web server.
2. **Linux root** — escalate to root on the web server.
3. **First domain credential** — obtain a working Active Directory credential
   (of any kind: password, hash, or ticket) for any domain principal.
4. **Privilege escalation** — obtain local administrator access on an internal
   Windows client.
5. **Domain Admin** — obtain Domain Admin equivalent access (a successful
   DCSync of `krbtgt` is sufficient proof on its own).

There is more than one way to reach several of these milestones. Not every
technique you find will lead anywhere real — some leads are genuine dead
ends, same as in a real engagement.

## Rules of engagement

- Stay inside `10.20.10.0/24`. Do not attempt to bridge, route, or pivot
  traffic to any network outside the lab.
- Standard pentest tooling is expected and allowed (BloodHound, Impacket,
  Certipy, Rubeus, mimikatz, sqlmap, ffuf, etc.) — this lab assumes their use.
- Have fun, and document your path as you go — the answer key you'll compare
  against afterward records the *intended* paths, not necessarily the only
  ones.
