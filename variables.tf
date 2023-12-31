variable "location" {
  description = "The region where the Data Factory will be created. This parameter is required"
  type        = string
  default     = "northeurope"
  nullable    = false
}

variable "resource_group_name" {
  description = "The name of the resource group in which the resources will be created. This parameter is required"
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Tags to be applied to resources."
  type        = map(string)
  default     = null
}

variable "name_sufix_append" {
  description = "Define if all resources names should be appended with sufixes according to https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations."
  type        = bool
  default     = true
  nullable    = false
}

variable "databricks" {
  type = object({
    name                                                = string
    sku                                                 = optional(string, "standard")
    load_balancer_backend_address_pool_id               = optional(string, null)
    customer_managed_key_enabled                        = optional(bool, false)
    managed_services_cmk_key_vault_key_id               = optional(string, null)
    managed_disk_cmk_key_vault_key_id                   = optional(string, null)
    managed_disk_cmk_rotation_to_latest_version_enabled = optional(bool, null)
    managed_resource_group_name                         = optional(string, null)
    infrastructure_encryption_enabled                   = optional(bool, false)
    public_network_access_enabled                       = optional(bool, true)
    network_security_group_rules_required               = optional(string, null)
    custom_parameters = optional(object({
      machine_learning_workspace_id = optional(string, null)
      nat_gateway_name              = optional(string, null)
      public_ip_name                = optional(string, null)
      no_public_ip                  = optional(bool, null)
      storage_account_name          = optional(string, null)
      storage_account_sku_name      = optional(string, "Standard_ZRS")
      vnet_address_prefix           = optional(string, null)
    }), {})
  })

  validation {
    condition     = can(index(["standard", "premium", "trial"], var.databricks.sku) >= 0)
    error_message = "Valid values are: standard, premium and trial"
  }

  validation {
    condition     = var.databricks.public_network_access_enabled ? true : can(index(["AllRules", "NoAzureDatabricksRules", "NoAzureServiceRules"], var.databricks.network_security_group_rules_required) >= 0)
    error_message = "If public_network_access_enabled is false, network_security_group_rules_required should be set to AllRules, NoAzureDatabricksRules or NoAzureServiceRules"
  }

  validation {
    condition     = try(var.databricks.custom_parameters.storage_account_sku_name, null) == null ? true : can(index(["Standard_LRS", "Standard_GRS", "Standard_RAGRS", "Standard_GZRS", "Standard_RAGZRS", "Standard_ZRS", "Premium_LRS", "Premium_ZRS"], var.databricks.custom_parameters.storage_account_sku_name) >= 0)
    error_message = "Valid values are Standard_LRS, Standard_GRS, Standard_RAGRS, Standard_GZRS, Standard_RAGZRS, Standard_ZRS, Premium_LRS and Premium_ZRS"
  }
}

variable "private_endpoints" {
  type = map(object({
    name                           = string
    subnet_id                      = string
    application_security_group_ids = optional(list(string))
    private_dns_zone_id            = string
  }))

  default = null
}

variable "vnet_injection" {
  type = object({
    vnet_id               = string
    nsg_name              = string
    route_table_id        = optional(string, null)
    container_snet_name   = string
    container_snet_prefix = string
    host_snet_name        = string
    host_snet_prefix      = string
  })

  default = null
}
