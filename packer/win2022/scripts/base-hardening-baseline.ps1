# Base-image baseline: current patches, then leave AV ON (posture role tunes
# it further per-host) and firewall ON (the posture role disables it later,
# per-deploy, after the domain join - the base image itself stays a normal
# default-hardened Windows install).
Install-WindowsUpdate -AcceptAll -AutoReboot -ErrorAction SilentlyContinue
Set-MpPreference -DisableRealtimeMonitoring $false
