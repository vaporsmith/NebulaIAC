variable "one_endpoint" {}
variable "one_username" {}
variable "one_password" {
  sensitive = true
}

variable "vm_template_name" {
  description = "Name of the OpenNebula VM template to use"
}

variable "network_name" {
  description = "Name of the OpenNebula network to use"
}

variable "vm_names" {
  description = "Set of VM names to create"
  type        = set(string)
}

variable "vm_cpu" {
  default = 1
}

variable "vm_vcpu" {
  default = 1
}

variable "vm_memory" {
  default = 512
}

variable "ssh_public_key_path" {
  default = "~/.ssh/ansible_id_rsa.pub"
}

variable "ansible_user" {
  default = "ansible"
}
