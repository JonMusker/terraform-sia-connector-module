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

#empty providers no longer need to be declared
#  provider "http" {}


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
  admin_password = random_password.vm_admin_password.result

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
# Install the ConnectorManager via script that was downloaded
# -------------------------------------------------------------------

resource "azurerm_virtual_machine_extension" "sia_connector_installer" {
  depends_on = [
    data.http.connector_install_script,
  ]

  name                 = "${var.vm_name}-sia-connector-installer"
  virtual_machine_id   = azurerm_windows_virtual_machine.connector_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"New-Item -ItemType Directory -Force -Path 'C:\\Temp' | Out-Null; Invoke-WebRequest -Uri '${local.script_url}' -OutFile 'C:\\Temp\\setup.ps1'; & 'C:\\Temp\\setup.ps1'\"" 
  })

  tags = var.tags
}

# -------------------------------------------------------------------
# CyberArk Identity: get token
# -------------------------------------------------------------------

# Requires x-www-form-urlencoded as the body, not json. A bit of fancy-footwork here to collapse
# all the input variables into an acceptable body as local.oauth_form_encoded
locals{
  oauth_form = {
    grant_type    = "client_credentials"
    client_id     = var.identity_client_id
    client_secret = var.identity_client_secret
    scope         = var.identity_scope
  }
  oauth_form_encoded = join("&",[
    for k,v in local.oauth_form : "${k}=${urlencode(v)}"
  ])
}

data "http" "cyberark_token" {
  depends_on = [
    azurerm_windows_virtual_machine.connector_vm,
  ]

  url    = var.identity_oauth_url
  method = "POST"

  request_headers = {
    Content-Type = "application/x-www-form-urlencoded"
    Accept = "application/json"
  }

  request_body = local.oauth_form_encoded
}

locals {
  cyberark_token = jsondecode(data.http.cyberark_token.response_body).access_token
}

# -------------------------------------------------------------------
# CyberArk CM API: get connector install script
# -------------------------------------------------------------------

data "http" "connector_install_script" {
  depends_on = [
    data.http.cyberark_token,
  ]

  url    = "${var.cm_api_base_url}/setup-script" # example; adjust path
  method = "POST"

  request_headers = {
    Authorization = "Bearer ${local.cyberark_token}"
    Accept        = "application/json"
  }

  request_body = jsonencode({
    os_type = "windows"
    connector_pool_id = var.connector_pool
  })
  # If CyberArk expects pool name as query param or header, add here:
  # url = "${var.cm_api_base_url}/cm/api/v1/agent/install-script?pool=${var.connector_pool}"
}
output "debug_script_url"{
  value = local.script_url
  sensitive=true
}

output "debug_raw_install_command"{
  value = local.raw_install_cmd
  sensitive=true
}

resource "local_file" "debug_regex_pattern"{
  content= local.regexpattern
  filename = "./debug.txt"
}

# The script comes back inside JSON.
# We want to just get the URL for the download out of the script
locals {
  raw_install_cmd = jsondecode(data.http.connector_install_script.response_body).script
  regexpattern = "SCRIPT_URL\\s*=.+(?P<uri>https:[^\"]+)\""  #actual regex we are aiming for is:   SCRIPT_URL\s*=.+"(?P<uri>https:[^"]+)"
  matches1 = regex(local.regexpattern, local.raw_install_cmd)  
  script_url = local.matches1["uri"]
}
