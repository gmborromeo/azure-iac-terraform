provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "main" {
    name        = "${var.project_name}-${var.environment}-rg"
    location    = var.location
    tags        = var.tags
}

module "networking" {
    source              = "./modules/networking"
    resource_group_name = azurerm_resource_group.main.name
    location            = var.location
    project_name        = var.project_name
    environment         = var.environment
    vnet_address_space  = var.vnet_address_space
    subnet_prefix       = var.subnet_prefix
    tags                = var.tags
}

module "vm" {
    source              = "./modules/vm"
    resource_group_name = azurerm_resource_group.main.name
    location            = var.location
    project_name        = var.project_name
    environment         = var.environment
    subnet_id           = module.networking.subnet_id
    vm_size             = var.vm_size
    admin_username      = var.admin_username
    ssh_public_key      = var.ssh_public_key
    tags                = var.tags
}