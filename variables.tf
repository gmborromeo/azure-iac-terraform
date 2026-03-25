variable "project_name" { default = "iac-demo" }
variable "environment" { default = "dev" }
variable "location" { default = "australiaeast" }
variable "vnet_address_space" { default = "10.0.0.0/16" }
variable "subnet_prefix" { default = "10.0.1.0/24" }
variable "vm_size" { default = "Standard_B2ts_v2" }
variable "admin_username" { default = "azureuser" }
variable "ssh_public_key" { default = "SSH public key content" }
variable "tags" {
  default = { managed_by = "terraform", project = "azure-iac" }
}