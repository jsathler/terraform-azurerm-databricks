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

resource "random_string" "default" {
  length    = 6
  min_lower = 6
}

module "adb" {
  source              = "../../"
  resource_group_name = azurerm_resource_group.default.name
  databricks = {
    name                        = "${local.prefix}${random_string.default.result}"
    managed_resource_group_name = replace(azurerm_resource_group.default.name, "rg", "mrg")
    custom_parameters = {
      no_public_ip = true
    }
  }
}

output "adb" {
  value = module.adb
}
