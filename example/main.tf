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
    random = {
      source = "hashicorp/random"
      version = "~>3.7"
    }
  }
}

provider "azurerm" {
  features {}
}

# Empty provider blocks no longer required
#       provider "http" {}
#       provider "random" {}

module "sia_connector" {
  source = "../modules/sia_connector"

  azure_tenant_id       = "2c6fb0b2-1423-4643-bb59-28243dbe4011"
  azure_subscription_id = "d66270fc-630f-4ade-b4d3-e2c134a1cae5"
  resource_group_name   = "RG1-WestEurope"
  location              = "westeurope"
  vnet_name             = "Vnet-RG1-WestEurope"
  subnet_name           = "default"

  vm_name        = "siawinconn01"
  vm_size        = "Standard_B2ms"
  admin_username = "cyberadm"

  cyberark_tenant_subdomain = "cctest1"
  identity_oauth_url        = "https://aax4093.id.cyberark.cloud/oauth2/platformtoken"
  identity_client_id        = "api-terraform-1@cyberark.cloud.10061"
  identity_client_secret    = var.identity_client_secret
  identity_scope            = "all"

  connector_pool = "cc9cd21e-bdcd-4667-84e1-4bd1c7d9aa5b" #AzureJM-Muskernet
  cm_api_base_url = "https://cctest1.connectormanagement.cyberark.cloud/api"

  tags = {
    Environment = "dev"
    Role        = "sia-connector"
  }
}
