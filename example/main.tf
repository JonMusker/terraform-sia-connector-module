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

provider "azurerm" {
  features {}
}

provider "http" {}

module "sia_connector" {
  source = "./modules/sia_connector"

  azure_tenant_id       = var.azure_tenant_id
  azure_subscription_id = var.azure_subscription_id
  resource_group_name   = var.resource_group_name
  location              = var.location

  vnet_name  = var.vnet_name
  subnet_name = var.subnet_name

  vm_name        = "sia-connector-01"
  vm_size        = "Standard_D2s_v5"
  admin_username = var.admin_username
  admin_password = var.admin_password

  cyberark_tenant_subdomain = var.cyberark_tenant_subdomain
  identity_oauth_url        = var.identity_oauth_url
  identity_client_id        = var.identity_client_id
  identity_client_secret    = var.identity_client_secret
  identity_scope            = var.identity_scope

  connector_pool = var.connector_pool
  cm_api_base_url = var.cm_api_base_url

  tags = {
    Environment = "dev"
    Role        = "sia-connector"
  }
}
