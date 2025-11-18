resource "local_file" "inventory_hosts" {
  for_each = opennebula_virtual_machine.vms

  filename = "${path.module}/inventory-hosts.yaml"
  content = yamlencode({
    group_name = var.ansible_group_name
    hosts = {
      for name, vm in opennebula_virtual_machine.vms :
      name => {
        ip = vm.ip
      }
    }
  })

  depends_on = [opennebula_virtual_machine.vms]
}

resource "null_resource" "generate_ansible_inventory" {
  depends_on = [local_file.inventory_hosts]

  provisioner "local-exec" {
    command = "cd ${path.module}/../.. && python3 scripts/generate_inventory.py"
  }
}


