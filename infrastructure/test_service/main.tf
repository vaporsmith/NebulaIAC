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

# Lookup the template ID by name
data "opennebula_template" "selected" {
  name = var.vm_template_name
}

# Lookup the network ID by name
data "opennebula_network" "selected" {
  name = var.network_name
}

resource "opennebula_virtual_machine" "vms" {
  for_each = toset(var.vm_names)

  name     = each.key
  cpu      = var.vm_cpu
  vcpu     = var.vm_vcpu
  memory   = var.vm_memory

  template_id = data.opennebula_template.selected.id

  nic {
    network_id = data.opennebula_network.selected.id
  }

  context = {
    SSH_PUBLIC_KEY = file(var.ssh_public_key_path)
    USERNAME       = var.ansible_user
  }
}
