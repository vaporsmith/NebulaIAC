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

resource "opennebula_virtual_machine" "vm_example" {
  name     = "terraform-test"
  cpu      = 1
  vcpu     = 1
  memory   = 512

  template_id = 6

  nic {
    network_id = 1
  }
}

