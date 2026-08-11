variable "one_endpoint" {}
variable "one_username" {}
variable "one_password" {
  sensitive = true
}

variable "ansible_group_name" {
  description = "The host group name to use in the Ansible inventory"
  default = "test_servers"
}

variable "ansible_user" {
  default = "ansible"
}

variable "ansible_ssh_private_key_file" {
  default = "../../ansible/ssh/id_ansible"
}

variable "vm_template_name" {
  description = "Name of the OpenNebula VM template to use"
  default = "Ubuntu Minimal 24.04"
}

variable "vm_image_name" {
  description = "Name of the OpenNebula VM image to use"
  default = "Ubuntu Minimal 24.04"
}

variable "network_name" {
  description = "Name of the OpenNebula network to use"
  default = "VMNet_bridged"
}

variable "vm_names" {
  description = "Set of VM names to create"
  type        = set(string)
  default = ["test_vm1", "test_vm2"]
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
  default = "../../ansible/ssh/id_ansible.pub"
}

variable "vm_disk_size_mb" {
  description = "Size of the VM disk in megabytes"
  type        = number
  default     = 20480  # 20 GB default
}

variable "worker_data_disk_enabled" {
  description = "Attach an additional raw volatile data disk to each kube worker VM for Rook/Ceph OSD use."
  type        = bool
  default     = false
}

variable "worker_data_disk_size_mb" {
  description = "Size of the additional worker data disk in megabytes. 256000 is roughly 250 GiB-ish depending on OpenNebula interpretation."
  type        = number
  default     = 256000
}

variable "worker_data_disk_target" {
  description = "Target device for the worker data disk. Expected inside Rocky workers as /dev/vdb when the OS disk is /dev/vda."
  type        = string
  default     = "vdb"
}

variable "worker_data_disk_driver" {
  description = "OpenNebula disk driver for the worker data disk."
  type        = string
  default     = "raw"
}

variable "worker_data_disk_volatile_type" {
  description = "OpenNebula volatile disk type for the worker data disk."
  type        = string
  default     = "fs"
}

variable "worker_data_disk_volatile_format" {
  description = "Filesystem/format selector for the OpenNebula volatile disk. Empty keeps the device raw/unformatted for Rook/Ceph."
  type        = string
  default     = ""
}

