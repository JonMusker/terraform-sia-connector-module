variable "azure_tenant_id" {
  type        = string
  description = "Azure AD tenant ID."
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group name where the VM will be created."
}

variable "location" {
  type        = string
  description = "Azure location."
}

variable "vnet_name" {
  type        = string
  description = "Existing virtual network name for the connector VM."
}

variable "subnet_name" {
  type        = string
  description = "Existing subnet name for the connector VM."
}

variable "vm_name" {
  type        = string
  description = "Name of the connector VM."
}

variable "vm_size" {
  type        = string
  description = "Azure VM size for the connector VM."
  default     = "Standard_D2s_v5"
}

variable "admin_username" {
  type        = string
  description = "Local admin username for the connector VM."
}

variable "admin_password" {
  type        = string
  description = "Local admin password for the connector VM."
  sensitive   = true
}

variable "cyberark_tenant_subdomain" {
  type        = string
  description = "CyberArk tenant subdomain (e.g. mytenant if URL is https://mytenant.id.cyberark.com)."
}

variable "identity_oauth_url" {
  type        = string
  description = "CyberArk Identity OAuth token endpoint URL."
}

variable "identity_client_id" {
  type        = string
  description = "Client ID used for CyberArk Identity OAuth."
}

variable "identity_client_secret" {
  type        = string
  description = "Client secret used for CyberArk Identity OAuth."
  sensitive   = true
}

variable "identity_scope" {
  type        = string
  description = "OAuth scope for CyberArk Identity token request."
  default     = "offline_access openid"
}

variable "connector_pool" {
  type        = string
  description = "CyberArk connector pool name or ID."
}

variable "cm_api_base_url" {
  type        = string
  description = "CyberArk Connector Management API base URL."
}

variable "winrm_port" {
  type        = number
  description = "WinRM HTTPS port."
  default     = 5986
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to Azure resources."
  default     = {}
}
