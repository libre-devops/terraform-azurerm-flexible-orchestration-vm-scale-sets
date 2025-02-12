module "shared_vars" {
  source = "libre-devops/shared-vars/azurerm"
}

locals {
  lookup_cidr = {
    for landing_zone, envs in module.shared_vars.cidrs : landing_zone => {
      for env, cidr in envs : env => cidr
    }
  }
}

module "subnet_calculator" {
  source = "libre-devops/subnet-calculator/null"

  base_cidr = local.lookup_cidr[var.short][var.env][0]
  subnets = {
    "AzureBastionSubnet" = {
      mask_size = 26
      netnum    = 0
    }
    "subnet1" = {
      mask_size = 26
      netnum    = 1
    }
  }
}

module "rg" {
  source = "libre-devops/rg/azurerm"

  rg_name  = "rg-${var.short}-${var.loc}-${var.env}-01"
  location = local.location
  tags     = local.tags
}

module "network" {
  source = "libre-devops/network/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  vnet_name          = "vnet-${var.short}-${var.loc}-${var.env}-01"
  vnet_location      = module.rg.rg_location
  vnet_address_space = [module.subnet_calculator.base_cidr]

  subnets = {
    for i, name in module.subnet_calculator.subnet_names :
    name => {
      address_prefixes = toset([module.subnet_calculator.subnet_ranges[i]])
    }
  }
}

module "nsg" {
  source = "libre-devops/nsg/azurerm"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  nsg_name              = "nsg-${var.short}-${var.loc}-${var.env}-01"
  associate_with_subnet = true
  subnet_id             = element(values(module.network.subnets_ids), 1)
  custom_nsg_rules = {
    "AllowVnetInbound" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "VirtualNetwork"
    }
  }
}

module "nat_gateway" {
  source = "../../../terraform-azurerm-nat-gateway"

  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  name                       = "natgw-${var.short}-${var.loc}-${var.env}-01"
  associate_nat_gw_to_subnet = true
  subnet_id                  = module.network.subnets_ids["subnet1"]
}

#
#module "bastion" {
#  source = "libre-devops/bastion/azurerm"
#
#  rg_name  = module.rg.rg_name
#  location = module.rg.rg_location
#  tags     = module.rg.rg_tags
#
#  bastion_host_name                  = "bst-${var.short}-${var.loc}-${var.env}-01"
#  create_bastion_nsg                 = true
#  create_bastion_nsg_rules           = true
#  create_bastion_subnet              = false
#  external_subnet_id                 = module.network.subnets_ids["AzureBastionSubnet"]
#  bastion_subnet_target_vnet_name    = module.network.vnet_name
#  bastion_subnet_target_vnet_rg_name = module.network.vnet_rg_name
#  bastion_subnet_range               = "10.0.1.0/27"
#}

resource "azurerm_application_security_group" "server_asg" {
  resource_group_name = module.rg.rg_name
  location            = module.rg.rg_location
  tags                = module.rg.rg_tags

  name = "asg-${var.short}-${var.loc}-${var.env}-01"
}


resource "azurerm_user_assigned_identity" "server_uid" {
  location            = module.rg.rg_location
  resource_group_name = module.rg.rg_name
  tags                = module.rg.rg_tags

  name = "uid-${var.short}-${var.loc}-${var.env}-01"
}

locals {
  name       = "vmss-${var.short}-${var.loc}-${var.env}01"
  admin_user = "LibreDevOpsAdmin"
}

module "windows_vm_scale_set" {
  source = "../../" # Adjust this path to where your module is located


  rg_name  = module.rg.rg_name
  location = module.rg.rg_location
  tags     = module.rg.rg_tags

  scale_sets = [
    {

      name                        = "${local.name}win"
      instances                   = 1
      sku                         = "Standard_B2ms"
      platform_fault_domain_count = 1


      os_profile = {
        windows_configuration = {
          admin_username           = "Local${title(var.short)}${title(var.env)}Admin"
          admin_password           = data.azurerm_key_vault_secret.admin_pwd.value
          computer_name_prefix     = "vmss1"
          enable_automatic_updates = true
          hotpatching_enabled      = false
          #          patch_mode               = "AutomaticByPlatform"
          #          patch_assessment_mode    = "AutomaticByPlatform"
          provision_vm_agent = true
          timezone           = "GMT Standard Time"
        }
      }

      vm_os_simple = "WindowsServer2022AzureEditionGen2"
      create_asg   = true

      identity_type = "UserAssigned"
      identity_ids  = [azurerm_user_assigned_identity.server_uid.id]
      network_interface = [
        {
          name                          = "nic-${local.name}win"
          primary                       = true
          enable_accelerated_networking = false
          ip_configuration = [
            {
              name                           = "ipconfig-${local.name}win"
              primary                        = true
              subnet_id                      = module.network.subnets_ids["subnet1"]
              application_security_group_ids = [azurerm_application_security_group.server_asg.id]
            }
          ]
        }
      ]
      os_disk = {
        caching              = "ReadWrite"
        storage_account_type = "StandardSSD_LRS"
        disk_size_gb         = 127
      }

      extension = [
        {
          name                       = "run-command-${local.name}win"
          publisher                  = "Microsoft.CPlat.Core"
          type                       = "RunCommandWindows"
          type_handler_version       = "1.1"
          auto_upgrade_minor_version = true
          settings = jsonencode({
            script = [
              "try { Install-WindowsFeature -Name FS-FileServer -IncludeManagementTools } catch { Write-Error 'Failed to install File Services: $_'; exit 1 }"
            ]
          })
        }
      ]
    },
    {

      name                        = "${local.name}lnx"
      instances                   = 1
      sku                         = "Standard_B2ms"
      platform_fault_domain_count = 1


      os_profile = {
        linux_configuration = {
          admin_username                  = "Local${title(var.short)}${title(var.env)}Admin"
          disable_password_authentication = true

          admin_ssh_key = {
            public_key = data.azurerm_ssh_public_key.mgmt_ssh_key.public_key
          }

          computer_name_prefix = "vmss2"
          #          patch_mode            = "AutomaticByPlatform"
          #          patch_assessment_mode = "AutomaticByPlatform"
          provision_vm_agent = true
          timezone           = "GMT Standard Time"
        }
      }

      vm_os_simple = "Ubuntu22.04"
      create_asg   = false

      identity_type = "SystemAssigned, UserAssigned"
      identity_ids  = [azurerm_user_assigned_identity.server_uid.id]
      network_interface = [
        {
          name                          = "nic-${local.name}lnx"
          primary                       = true
          enable_accelerated_networking = false
          ip_configuration = [
            {
              name                           = "ipconfig-${local.name}lnx"
              primary                        = true
              subnet_id                      = module.network.subnets_ids["subnet1"]
              application_security_group_ids = [azurerm_application_security_group.server_asg.id]
            }
          ]
        }
      ]
      os_disk = {
        caching              = "ReadWrite"
        storage_account_type = "StandardSSD_LRS"
        disk_size_gb         = 127
      }

      extension = [
        {
          name                       = "run-command-${local.name}lnx"
          publisher                  = "Microsoft.CPlat.Core"
          type                       = "RunCommandLinux"
          type_handler_version       = "1.0"
          auto_upgrade_minor_version = true
          protected_settings = jsonencode({
            commandToExecute = tostring("apt-get update && apt-get dist-upgrade && apt-get install -y nginx")
          })
        }
      ]
    }
  ]
}
