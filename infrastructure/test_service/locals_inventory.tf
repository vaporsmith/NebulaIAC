resource "local_file" "inventory_hosts" {
  content = yamlencode({
    group_name = var.ansible_group_name
    hosts = [
      for name, vm in opennebula_virtual_machine.vms :
      {
        ip                           = vm.nic[0].ip
        ansible_user                 = var.ansible_user
        ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
      }
    ]
  })

  filename = "${path.module}/inventory-hosts.yaml"
  depends_on = [opennebula_virtual_machine.vms]
}
