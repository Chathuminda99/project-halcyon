packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/22.04/ubuntu-22.04.4-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "none" # pin the sha256 from releases.ubuntu.com/22.04/SHA256SUMS
}

source "vmware-iso" "ubuntu2204" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  guest_os_type    = "ubuntu-64"
  communicator     = "ssh"
  ssh_username     = "vagrant"
  ssh_password     = "vagrant"
  ssh_timeout      = "2h"
  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"
  cpus             = 2
  memory           = 1536
  disk_size        = 30000
  version          = 19
  headless         = true

  http_directory = "packer/ubuntu2204/http"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10>"
  ]
  boot_wait = "5s"
}

build {
  sources = ["source.vmware-iso.ubuntu2204"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get -y upgrade",
      "sudo apt-get -y install open-vm-tools",
      "echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant"
    ]
  }
}
