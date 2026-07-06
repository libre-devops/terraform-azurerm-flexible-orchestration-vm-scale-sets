locals {
  location  = lookup(var.regions, var.loc, "uksouth")
  rg_name   = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  vnet_name = "vnet-${var.short}-${var.loc}-${terraform.workspace}-001"
  vmss_name = "vmss${var.short}${var.loc}${terraform.workspace}001"
  snet_app  = "snet-app-${local.vnet_name}"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "network" {
  source  = "libre-devops/network/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  vnet_name     = local.vnet_name
  address_space = ["10.0.0.0/16"]
  subnets       = { (local.snet_app) = { address_prefixes = ["10.0.1.0/24"] } }
}

# A placeholder public key: nothing in the example ever logs in. Real callers bring their own.
locals {
  example_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example"
}

# Minimal call: one Linux flexible scale set, one instance, one NIC, SSH-only auth, an image from
# the catalog, and the module defaults (zone-redundant, fault domain count 1, managed boot
# diagnostics).
module "flex_vmss" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  scale_sets = {
    (local.vmss_name) = {
      sku_name  = "Standard_D2lds_v6"
      instances = 1

      source_image_simple = "Ubuntu2404"

      os_profile = {
        linux = {
          admin_username = "azureuser"
          admin_ssh_keys = [{ public_key = local.example_public_key }]
        }
      }

      network_interfaces = {
        "nic" = {
          ip_configurations = {
            "internal" = { subnet_id = module.network.subnet_ids[local.snet_app] }
          }
        }
      }
    }
  }
}
