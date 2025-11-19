terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# Normally, providers are configured in the root module and passed in.
# This is here as a sketch; you can remove and use `provider` blocks in root + aliases.
provider "azurerm" {
  features        {}
  tenant_id       = var.azure_tenant_id
  subscription_id = var.azure_subscription_id
}

provider "http" {}

# -------------------------------------------------------------------
# Networking lookups
# -------------------------------------------------------------------

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
}

# -------------------------------------------------------------------
# Public IP + NIC
# -------------------------------------------------------------------

resource "azurerm_public_ip" "vm_pip" {
  name                = "${var.vm_name}-pip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.vm_name}-nic"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Windows VM
# -------------------------------------------------------------------

resource "azurerm_windows_virtual_machine" "connector_vm" {
  name                = var.vm_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [azurerm_network_interface.vm_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = var.tags
}

# -------------------------------------------------------------------
# Enable WinRM via VM extension (placeholder script)
# -------------------------------------------------------------------

resource "azurerm_virtual_machine_extension" "enable_winrm" {
  name                 = "${var.vm_name}-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.connector_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  # Replace with your actual WinRM-enabling script
  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"<your WinRM setup script here>\""
  })

  tags = var.tags
}

# -------------------------------------------------------------------
# CyberArk Identity: get token
# -------------------------------------------------------------------

data "http" "cyberark_token" {
  url    = var.identity_oauth_url
  method = "POST"

  request_headers = {
    Content-Type = "application/json"
  }

  request_body = jsonencode({
    client_id     = var.identity_client_id
    client_secret = var.identity_client_secret
    scope         = var.identity_scope
    grant_type    = "client_credentials"
    # adjust payload as per CyberArk Identity requirements
  })
}

locals {
  cyberark_token = jsondecode(data.http.cyberark_token.response_body).access_token
}

# -------------------------------------------------------------------
# CyberArk CM API: get connector install script
# -------------------------------------------------------------------

data "http" "connector_install_script" {
  url    = "${var.cm_api_base_url}/cm/api/v1/agent/install-script" # example; adjust path
  method = "GET"

  request_headers = {
    Authorization = "Bearer ${local.cyberark_token}"
    Accept        = "application/json"
  }

  # If CyberArk expects pool name as query param or header, add here:
  # url = "${var.cm_api_base_url}/cm/api/v1/agent/install-script?pool=${var.connector_pool}"
}

# Assume the script comes back either as plain text or inside JSON.
# Adjust parsing accordingly.
locals {
  connector_script = data.http.connector_install_script.response_body
  # or jsondecode(...).script if API wraps it in JSON
}

# -------------------------------------------------------------------
# Run connector install script via WinRM
# -------------------------------------------------------------------

resource "null_resource" "install_sia_connector" {
  depends_on = [
    azurerm_windows_virtual_machine.connector_vm,
    azurerm_virtual_machine_extension.enable_winrm,
  ]

  triggers = {
    vm_id        = azurerm_windows_virtual_machine.connector_vm.id
    script_sha1  = sha1(local.connector_script)
    connector_po = var.connector_pool
  }

  connection {
    type     = "winrm"
    host     = azurerm_public_ip.vm_pip.ip_address
    user     = var.admin_username
    password = var.admin_password

    port     = var.winrm_port
    https    = true
    insecure = true # tighten later if you manage certs
  }

  provisioner "file" {
    content     = local.connector_script
    destination = "C:/Temp/install_sia_connector.ps1"
  }

  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -File C:/Temp/install_sia_connector.ps1 -ConnectorPool '${var.connector_pool}'",
      # adjust arguments to match CyberArk script
      "powershell Start-Sleep -Seconds 300"
    ]
  }
}
