# -*- mode: ruby -*-
# Project Halcyon — VMware Workstation topology.
# Six VMs on one flat, isolated, host-only network. No firewall between hosts
# (Windows Defender Firewall is disabled by the posture role; Defender AV stays on).
#
# This file ONLY defines VM lifecycle (boot, network, sizing) - it does NOT
# provision them. Provisioning is a separate, explicit `ansible-playbook`
# step in scripts/deploy.sh, run after `vagrant up` rather than via Vagrant's
# built-in "ansible" provisioner. That's a deliberate choice, not laziness:
# on a Windows host, `vagrant` runs as a native Windows binary, and Ansible
# has no supported Windows control node, so the built-in provisioner (which
# shells out to `ansible-playbook` on the same OS running `vagrant`) simply
# cannot work there - provisioning has to run from WSL2 instead. Keeping
# both host OSes on one code path (this same decoupled flow) rather than
# branching Windows vs. Linux behavior in the Vagrantfile itself. See
# README.md's "Host OS: Linux vs. Windows" section.

require 'yaml'

VAGRANTFILE_API_VERSION = "2"
NETWORK = "10.20.10.0/24"
VMNET   = ENV.fetch("HALCYON_VMNET", "vmnet20")

# host-only static IPs, kept in sync with ansible/inventory.yml
HOSTS = {
  "dc01"   => { ip: "10.20.10.10", box: "halcyon/win2022",  cpus: 2, mem: 3072, gui: false },
  "srv01"  => { ip: "10.20.10.20", box: "halcyon/win2022",  cpus: 2, mem: 3072, gui: false },
  "ws01"   => { ip: "10.20.10.31", box: "halcyon/win11",    cpus: 2, mem: 2560, gui: true  },
  "ws02"   => { ip: "10.20.10.32", box: "halcyon/win11",    cpus: 2, mem: 2560, gui: true  },
  "web01"  => { ip: "10.20.10.40", box: "halcyon/ubuntu22", cpus: 2, mem: 1536, gui: false },
  "attack" => { ip: "10.20.10.66", box: "kalilinux/rolling", cpus: 2, mem: 3072, gui: false },
}

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  HOSTS.each do |name, spec|
    config.vm.define name do |node|
      node.vm.box = spec[:box]
      node.vm.hostname = name

      # Single host-only network, static IP, no NAT'd internet access by default.
      node.vm.network "private_network",
        ip: spec[:ip],
        vmware__vmnet: VMNET

      node.vm.provider "vmware_desktop" do |v|
        v.gui = spec[:gui]
        v.vmx["memsize"] = spec[:mem].to_s
        v.vmx["numvcpus"] = spec[:cpus].to_s
        v.vmx["ethernet0.virtualdev"] = "e1000e"
        # Isolation: never bridge, never attach to a real-LAN vmnet.
        v.vmx["ethernet0.connectiontype"] = "custom"
      end

      if name.start_with?("ws") || name == "dc01" || name == "srv01"
        node.vm.communicator = "winrm"
        node.winrm.username = "vagrant"
        node.winrm.password = "vagrant" # bootstrap only; rotated by randomize role
        node.winrm.transport = :negotiate
        node.winrm.basic_auth_only = false
      else
        node.vm.communicator = "ssh"
      end

      # No provisioner block here on purpose - see the header comment.
      # scripts/deploy.sh runs `ansible-playbook` separately after `vagrant up`.
    end
  end
end
