output "vm_name" {
  value = azurerm_windows_virtual_machine.connector_vm.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.vm_pip.ip_address
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  value     = var.admin_password
  sensitive = true
}
