output "vm_ips" {
  value = {
    for name, vm in opennebula_virtual_machine.vms :
    name => vm.nic[0].ip
  }
}
