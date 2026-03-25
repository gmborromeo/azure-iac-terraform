terraform {
    required_version = ">= 1.5.0"
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "~> 3.0"
        }
    }

    backend "azurerm" {
        resource_group_name     = "terraform-state-rg"
        storage_account_name    = "tfstate3946"
        container_name          = "tfstate"
        key                     = "azure-iac.tfstate"
    }
}