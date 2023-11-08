locals {
  prefix = "${basename(path.cwd)}-example"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "default" {
  name     = "${local.prefix}-rg"
  location = "northeurope"
}

resource "azurerm_virtual_network" "default" {
  name                = "${local.prefix}-vnet"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_route_table" "default" {
  name                = "${local.prefix}-route"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
}

locals {
  adb_ne_routes = [
    { name = "adb-servicetag", address_prefix = "AzureDatabricks", next_hop_type = "Internet", next_hop_in_ip_address = null },
    { name = "adb-extinfra", address_prefix = "20.73.215.48/28", next_hop_type = "Internet", next_hop_in_ip_address = null },
    { name = "adb-metastore", address_prefix = "Sql.NorthEurope", next_hop_type = "Internet", next_hop_in_ip_address = null },
    { name = "adb-storage", address_prefix = "Storage.NorthEurope", next_hop_type = "Internet", next_hop_in_ip_address = null },
    { name = "adb-eventhub", address_prefix = "EventHub.NorthEurope", next_hop_type = "Internet", next_hop_in_ip_address = null },
    #{ name = "deafult", address_prefix = "0.0.0.0/0", next_hop_type = "VirtualAppliance", next_hop_in_ip_address = "10.0.10.4" }
  ]
}

resource "azurerm_route" "default" {
  for_each               = { for key, value in local.adb_ne_routes : value.name => value }
  name                   = "${each.key}-rt"
  resource_group_name    = azurerm_resource_group.default.name
  route_table_name       = azurerm_route_table.default.name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = each.value.next_hop_in_ip_address
}

module "adb" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name

  databricks = {
    name                        = local.prefix
    managed_resource_group_name = replace(azurerm_resource_group.default.name, "rg", "mrg")
    custom_parameters = {
      no_public_ip = true
    }
  }

  vnet_injection = {
    vnet_id               = azurerm_virtual_network.default.id
    nsg_name              = local.prefix
    route_table_id        = azurerm_route_table.default.id
    container_snet_name   = "${local.prefix}-cont"
    container_snet_prefix = "10.0.1.0/24"
    host_snet_name        = "${local.prefix}-host"
    host_snet_prefix      = "10.0.2.0/24"
  }
}

output "adb" {
  value = module.adb
}
