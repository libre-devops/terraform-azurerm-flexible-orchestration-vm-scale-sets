locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  vnet_name  = "vnet-${var.short}-${var.loc}-${terraform.workspace}-002"
  lb_name    = "lbi-${var.short}-${var.loc}-${terraform.workspace}-002"
  vmss_linux = "vmss${var.short}${var.loc}${terraform.workspace}002"
  vmss_win   = "vmss${var.short}${var.loc}${terraform.workspace}003"
  snet_app   = "snet-app-${local.vnet_name}"

  # A placeholder public key: nothing in the example ever logs in. Real callers bring their own.
  example_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-flexible-orchestration-vm-scale-sets" }
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

# An internal load balancer whose backend pool the Linux scale set joins.
module "private_lb" {
  source  = "libre-devops/private-lb/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  lbs = {
    (local.lb_name) = {
      frontend_ip_configurations = {
        "internal" = { subnet_id = module.network.subnet_ids[local.snet_app] }
      }
      backend_pools = { "app" = {} }
      probes        = { "tcp-8080" = { port = 8080 } }
      rules = {
        "app-8080" = {
          frontend_port     = 80
          backend_port      = 8080
          backend_pool_keys = ["app"]
          probe_key         = "tcp-8080"
        }
      }
    }
  }
}

resource "random_password" "windows_admin" {
  length      = 24
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

# Complete call: a Linux scale set exercising the full surface (load balancer pool membership,
# Application Health extension with automatic instance repair, termination notification, a data
# disk, user_data, custom fault domain and zone settings), plus a Windows scale set with automatic
# updates and a timezone. Spot capacity, mixed-size sku profiles, and rolling upgrades are covered
# by the mocked tests: they are legal to apply but hostage to spot capacity and upgrade timing in a
# short-lived E2E.
module "flex_vmss" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  scale_sets = {
    (local.vmss_linux) = {
      sku_name  = "Standard_D2lds_v6"
      instances = 1

      source_image_simple = "Ubuntu2404"
      user_data           = "#!/usr/bin/env bash\necho flex > /tmp/flex.txt\n"

      os_profile = {
        linux = {
          admin_username       = "azureuser"
          admin_ssh_keys       = [{ public_key = local.example_public_key }]
          computer_name_prefix = "flexlnx"
        }
      }

      os_disk = { storage_account_type = "Premium_LRS", disk_size_gb = 64 }

      data_disks = [
        { disk_size_gb = 32, create_option = "Empty" }
      ]

      network_interfaces = {
        "nic" = {
          accelerated_networking_enabled = true
          ip_configurations = {
            "internal" = {
              subnet_id                              = module.network.subnet_ids[local.snet_app]
              load_balancer_backend_address_pool_ids = [module.private_lb.backend_pool_ids["${local.lb_name}/app"]]
            }
          }
        }
      }

      extensions = {
        "HealthExtension" = {
          publisher            = "Microsoft.ManagedServices"
          type                 = "ApplicationHealthLinux"
          type_handler_version = "1.0"
          settings             = jsonencode({ protocol = "tcp", port = 8080 })
        }
      }

      automatic_instance_repair = { enabled = true, grace_period = "PT10M" }
      termination_notification  = { enabled = true, timeout = "PT5M" }
    }

    (local.vmss_win) = {
      sku_name  = "Standard_D2lds_v6"
      instances = 1

      source_image_simple = "WindowsServer2022AzureEdition"

      os_profile = {
        windows = {
          admin_username       = "azureadmin"
          admin_password       = random_password.windows_admin.result
          computer_name_prefix = "flexwin"
          timezone             = "GMT Standard Time"
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
