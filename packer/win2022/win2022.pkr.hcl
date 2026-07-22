packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
    vagrant = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

variable "iso_url" {
  type        = string
  description = "Path or URL to the Windows Server 2022 evaluation ISO (Microsoft Evaluation Center)"
}

variable "iso_checksum" {
  type    = string
  default = "none" # set to sha256:<hash> once you have the ISO
}

source "vmware-iso" "win2022" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  guest_os_type    = "windows2019srv-64"
  communicator     = "winrm"
  winrm_username   = "vagrant"
  winrm_password   = "vagrant"
  winrm_timeout    = "6h"
  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer shutdown\""
  cpus             = 2
  memory           = 3072
  disk_size        = 60000
  version          = 19
  headless         = true

  floppy_files = [
    "packer/win2022/autounattend.xml",
    "packer/win2022/scripts/enable-winrm.ps1",
  ]

  vmx_data = {
    "ethernet0.virtualDev" = "e1000e"
  }
}

build {
  sources = ["source.vmware-iso.win2022"]

  provisioner "windows-restart" {}

  provisioner "powershell" {
    script = "packer/win2022/scripts/base-hardening-baseline.ps1"
  }

  provisioner "windows-restart" {}

  post-processor "vagrant" {
    output             = "packer/win2022/halcyon-win2022.box"
    provider_override  = "vmware_desktop"
  }
}
