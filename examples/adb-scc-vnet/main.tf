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
module "vnet" {
  source              = "jsathler/network/azurerm"
  version             = "0.0.2"
  name                = local.prefix
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  address_space       = ["10.0.0.0/16"]

  subnets = {
    adb-container = {
      address_prefixes   = ["10.0.0.0/23"]
      nsg_create_default = false
      service_delegation = {
        name = "Microsoft.Databricks/workspaces"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
          "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
          "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
        ]
      }
      #service_endpoints = ["Microsoft.Sql"]
    }
    adb-host = {
      address_prefixes   = ["10.0.2.0/23"]
      nsg_create_default = false
      service_delegation = {
        name = "Microsoft.Databricks/workspaces"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
          "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
          "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
        ]
      }
      #service_endpoints  = ["Microsoft.Sql"]
    }
  }
}

resource "azurerm_network_security_group" "default" {
  name                = "${local.prefix}-nsg"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_subnet_network_security_group_association" "default" {
  for_each                  = { for key, value in module.vnet.subnet_ids : key => value }
  network_security_group_id = azurerm_network_security_group.default.id
  subnet_id                 = each.value
}

module "adb" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name
  databricks = {
    name                        = local.prefix
    managed_resource_group_name = replace(azurerm_resource_group.default.name, "rg", "mrg")
    custom_parameters = {
      no_public_ip                                         = true
      virtual_network_id                                   = module.vnet.vnet_id
      private_subnet_name                                  = "adb-container-snet"
      public_subnet_name                                   = "adb-host-snet"
      public_subnet_network_security_group_association_id  = azurerm_network_security_group.default.id
      private_subnet_network_security_group_association_id = azurerm_network_security_group.default.id
    }
  }
}

output "adb" {
  value = module.adb
}
