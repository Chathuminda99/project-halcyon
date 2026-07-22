# Bootstraps WinRM so Packer (and later Vagrant/Ansible) can drive the VM.
# Runs once via FirstLogonCommands in autounattend.xml.
winrm quickconfig -quiet
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
Set-Service -Name WinRM -StartupType Automatic
Restart-Service WinRM
