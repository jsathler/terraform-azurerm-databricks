locals {
  tags = merge(var.tags, { ManagedByTerraform = "True" })
}

###########
# Networking
# Since each ADB instance requires dedicated subnets, we decided to include subnet and nsg resources on this module
###########

data "azurerm_virtual_network" "default" {
  count               = var.vnet_injection == null ? 0 : 1
  name                = split("/", var.vnet_injection.vnet_id)[8]
  resource_group_name = split("/", var.vnet_injection.vnet_id)[4]
}

resource "azurerm_subnet" "container" {
  count                = var.vnet_injection == null ? 0 : 1
  name                 = var.name_sufix_append ? "${var.vnet_injection.container_snet_name}-snet" : var.vnet_injection.container_snet_name
  resource_group_name  = data.azurerm_virtual_network.default[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.default[0].name
  address_prefixes     = [var.vnet_injection.container_snet_prefix]

  delegation {
    name = "delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "host" {
  count                = var.vnet_injection == null ? 0 : 1
  name                 = var.name_sufix_append ? "${var.vnet_injection.host_snet_name}-snet" : var.vnet_injection.host_snet_name
  resource_group_name  = data.azurerm_virtual_network.default[0].resource_group_name
  virtual_network_name = data.azurerm_virtual_network.default[0].name
  address_prefixes     = [var.vnet_injection.host_snet_prefix]

  delegation {
    name = "delegation"

    service_delegation {
      name = "Microsoft.Databricks/workspaces"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_network_security_group" "default" {
  count               = var.vnet_injection == null ? 0 : 1
  name                = var.name_sufix_append ? "${var.vnet_injection.nsg_name}-nsg" : var.vnet_injection.nsg_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "container" {
  count                     = var.vnet_injection == null ? 0 : 1
  network_security_group_id = azurerm_network_security_group.default[0].id
  subnet_id                 = azurerm_subnet.container[0].id
}

resource "azurerm_subnet_network_security_group_association" "host" {
  count                     = var.vnet_injection == null ? 0 : 1
  network_security_group_id = azurerm_network_security_group.default[0].id
  subnet_id                 = azurerm_subnet.host[0].id
}

resource "azurerm_subnet_route_table_association" "container" {
  count          = try(var.vnet_injection.route_table_id, null) == null ? 0 : 1
  subnet_id      = azurerm_subnet.container[0].id
  route_table_id = var.vnet_injection.route_table_id
}

resource "azurerm_subnet_route_table_association" "host" {
  count          = try(var.vnet_injection.route_table_id, null) == null ? 0 : 1
  subnet_id      = azurerm_subnet.host[0].id
  route_table_id = var.vnet_injection.route_table_id
}

###########
# Databricks
###########

resource "azurerm_databricks_workspace" "default" {
  name                                                = var.name_sufix_append ? "${var.databricks.name}-dbw" : var.databricks.name
  resource_group_name                                 = var.resource_group_name
  location                                            = var.location
  sku                                                 = var.databricks.sku
  load_balancer_backend_address_pool_id               = var.databricks.load_balancer_backend_address_pool_id
  managed_services_cmk_key_vault_key_id               = var.databricks.managed_services_cmk_key_vault_key_id
  managed_disk_cmk_key_vault_key_id                   = var.databricks.managed_disk_cmk_key_vault_key_id
  managed_disk_cmk_rotation_to_latest_version_enabled = var.databricks.managed_disk_cmk_rotation_to_latest_version_enabled
  managed_resource_group_name                         = var.databricks.managed_resource_group_name
  customer_managed_key_enabled                        = var.databricks.customer_managed_key_enabled
  infrastructure_encryption_enabled                   = var.databricks.infrastructure_encryption_enabled
  public_network_access_enabled                       = var.databricks.public_network_access_enabled
  network_security_group_rules_required               = var.databricks.network_security_group_rules_required
  tags                                                = local.tags

  dynamic "custom_parameters" {
    for_each = var.databricks.custom_parameters == null ? [] : [var.databricks.custom_parameters]
    content {
      machine_learning_workspace_id                        = custom_parameters.value.machine_learning_workspace_id
      nat_gateway_name                                     = custom_parameters.value.nat_gateway_name
      public_ip_name                                       = custom_parameters.value.public_ip_name
      no_public_ip                                         = custom_parameters.value.no_public_ip
      public_subnet_name                                   = try(azurerm_subnet.container[0].name, null)
      public_subnet_network_security_group_association_id  = try(azurerm_network_security_group.default[0].id, null)
      private_subnet_name                                  = try(azurerm_subnet.host[0].name, null)
      private_subnet_network_security_group_association_id = try(azurerm_network_security_group.default[0].id, null)
      storage_account_name                                 = custom_parameters.value.storage_account_name
      storage_account_sku_name                             = custom_parameters.value.storage_account_sku_name
      virtual_network_id                                   = try(data.azurerm_virtual_network.default[0].id, null)
      vnet_address_prefix                                  = custom_parameters.value.vnet_address_prefix
    }
  }
}
