terraform {
  required_providers {
    opennebula = {
      source = "OpenNebula/opennebula"
    }
  }
}

provider "opennebula" {
  endpoint = var.one_endpoint
  username = var.one_username
  password = var.one_password
}

data "opennebula_image" "ubuntu_minimal" {
  name = "Ubuntu Minimal 22.04"
}

variable "network_id" {
  description = "OpenNebula virtual network ID to attach"
}

resource "opennebula_virtual_machine" "vms" {
  for_each = toset(var.vm_names)

  name   = each.key
  cpu    = var.vm_cpu
  vcpu   = var.vm_vcpu
  memory = var.vm_memory

  os {
    boot = "disk0"
    arch = "x86_64"
  }

  disk {
    image_id = data.opennebula_image.ubuntu_minimal.id
    size     = var.vm_disk_size_mb
    target   = "vda"
    driver   = "qcow2"
  }

  nic {
    network_id = var.network_id
    model = "virtio"
  }

  graphics { 
    type = "vnc" 
    listen = "0.0.0.0" 
  }

  context = {
    NETWORK        = "YES"
    HOSTNAME       = each.key
    SSH_PUBLIC_KEY = file(var.ssh_public_key_path)
    USERNAME       = var.ansible_user
    GROW_ROOTFS    = "YES"
  }

  on_disk_change = "RECREATE"
}


