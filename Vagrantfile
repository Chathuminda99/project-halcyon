# -*- mode: ruby -*-
# Project Halcyon — VMware Workstation topology.
# Six VMs on one flat, isolated, host-only network. No firewall between hosts
# (Windows Defender Firewall is disabled by the posture role; Defender AV stays on).

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

      node.vm.provision "ansible" do |ansible|
        ansible.compatibility_mode = "2.0"
        ansible.playbook = "ansible/site.yml"
        ansible.inventory_path = "ansible/inventory.yml"
        ansible.limit = name
        ansible.extra_vars = { halcyon_deploy_seed: ENV.fetch("HALCYON_SEED", "") }
      end
    end
  end
end
