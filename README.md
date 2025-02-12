```hcl
resource "azurerm_orchestrated_virtual_machine_scale_set" "scale_set" {
  for_each                     = { for vm in var.scale_sets : vm.name => vm }
  name                         = each.value.name
  resource_group_name          = var.rg_name
  location                     = var.location
  tags                         = var.tags
  platform_fault_domain_count  = each.value.platform_fault_domain_count
  instances                    = try(each.value.instances, null)
  sku_name                     = try(each.value.sku, null)
  max_bid_price                = each.value.max_bid_price
  priority                     = each.value.priority
  user_data_base64             = each.value.user_data_base64
  proximity_placement_group_id = each.value.proximity_placement_group_id
  zone_balance                 = each.value.zone_balance
  zones                        = each.value.zones
  single_placement_group       = each.value.single_placement_group
  source_image_id              = try(each.value.use_custom_image, null) == true ? each.value.custom_source_image_id : null
  encryption_at_host_enabled   = each.value.encryption_at_host_enabled

  dynamic "os_profile" {
    for_each = each.value.os_profile != null ? [each.value.os_profile] : []
    content {
      custom_data = os_profile.value.custom_data

      dynamic "windows_configuration" {
        for_each = os_profile.value.windows_configuration != null ? [os_profile.value.windows_configuration] : []
        content {
          admin_username           = windows_configuration.value.admin_username
          admin_password           = windows_configuration.value.admin_password
          computer_name_prefix     = windows_configuration.value.computer_name_prefix
          enable_automatic_updates = windows_configuration.value.enable_automatic_updates
          hotpatching_enabled      = windows_configuration.value.hotpatching_enabled
          patch_assessment_mode    = windows_configuration.value.patch_assessment_mode
          patch_mode               = windows_configuration.value.patch_mode
          provision_vm_agent       = windows_configuration.value.provision_vm_agent
          timezone                 = windows_configuration.value.timezone

          #Bug? Unexpected but docs say it is
          #          dynamic "additional_unattend_content" {
          #            for_each = windows_configuration.additional_unattend_content != null ? windows_configuration.value.additional_unattend_content : []
          #            content {
          #              content = additional_unattend_content.value.content
          #              setting = additional_unattend_content.value.setting
          #            }
          #          }

          dynamic "winrm_listener" {
            for_each = windows_configuration.value.winrm_listener != null ? windows_configuration.value.winrm_listener : []
            content {
              protocol        = winrm_listener.value.protocol
              certificate_url = winrm_listener.value.certificate_url
            }
          }

          dynamic "secret" {
            for_each = windows_configuration.value.secret != null ? windows_configuration.value.secret : []
            content {
              key_vault_id = secret.value.key_vault_id

              dynamic "certificate" {
                for_each = secret.value.certificate
                content {
                  store = certificate.value.store
                  url   = certificate.value.url
                }
              }
            }
          }
        }
      }

      dynamic "linux_configuration" {
        for_each = os_profile.value.linux_configuration != null ? [os_profile.value.linux_configuration] : []
        content {
          admin_username                  = linux_configuration.value.admin_username
          admin_password                  = linux_configuration.value.admin_ssh_key != null && linux_configuration.value.disable_password_authentication == true ? null : linux_configuration.value.admin_password
          computer_name_prefix            = linux_configuration.value.computer_name_prefix
          disable_password_authentication = linux_configuration.value.disable_password_authentication
          patch_assessment_mode           = linux_configuration.value.patch_assessment_mode
          patch_mode                      = linux_configuration.value.patch_mode
          provision_vm_agent              = linux_configuration.value.provision_vm_agent

          dynamic "admin_ssh_key" {
            for_each = linux_configuration.value.admin_ssh_key != null ? [linux_configuration.value.admin_ssh_key] : []
            content {
              public_key = admin_ssh_key.value.public_key
              username   = admin_ssh_key.value.username != null ? admin_ssh_key.value.username : linux_configuration.value.admin_username
            }
          }

          dynamic "secret" {
            for_each = linux_configuration.value.secret != null ? linux_configuration.value.secret : []
            content {
              key_vault_id = secret.value.key_vault_id

              dynamic "certificate" {
                for_each = secret.value.certificate
                content {
                  url = certificate.value.url
                }
              }
            }
          }
        }
      }
    }
  }

  dynamic "priority_mix" {
    for_each = each.value.priority_mix != null ? [each.value.priority_mix] : []
    content {
      base_regular_count            = priority_mix.value.base_regular_count
      regular_percentage_above_base = priority_mix.value.regular_percentage_above_base
    }
  }

  dynamic "termination_notification" {
    for_each = each.value.termination_notification != null ? [each.value.termination_notification] : []
    content {
      enabled = termination_notification.value.enabled
      timeout = termination_notification.value.timeout
    }
  }

  os_disk {
    caching                   = try(each.value.os_disk.caching, null)
    storage_account_type      = try(each.value.os_disk.storage_account_type, null)
    disk_size_gb              = try(each.value.os_disk.disk_size_gb, null)
    disk_encryption_set_id    = try(each.value.os_disk.disk_encryption_set_id, null)
    write_accelerator_enabled = try(each.value.os_disk.write_accelerator_enabled, false)

    dynamic "diff_disk_settings" {
      for_each = each.value.os_disk.diff_disk_settings != null ? [each.value.os_disk.diff_disk_settings] : []
      content {
        option    = diff_disk_settings.value.option
        placement = diff_disk_settings.value.placement
      }
    }
  }

  dynamic "data_disk" {
    for_each = each.value.data_disk != null ? toset(each.value.data_disk) : []
    content {
      lun                            = data_disk.value.lun
      create_option                  = data_disk.value.create_option
      caching                        = data_disk.value.caching
      storage_account_type           = data_disk.value.storage_account_type
      disk_size_gb                   = data_disk.value.disk_size_gb
      write_accelerator_enabled      = data_disk.value.write_accelerator_enabled
      disk_encryption_set_id         = data_disk.value.disk_encryption_set_id
      ultra_ssd_disk_iops_read_write = data_disk.value.ultra_ssd_disk_iops_read_write
      ultra_ssd_disk_mbps_read_write = data_disk.value.ultra_ssd_disk_mbps_read_write

    }
  }

  dynamic "extension" {
    for_each = each.value.extension != null ? toset(each.value.extension) : []
    content {
      name                                = extension.value.name
      publisher                           = extension.value.publisher
      type                                = extension.value.type
      type_handler_version                = extension.value.type_handler_version
      auto_upgrade_minor_version_enabled  = extension.value.auto_upgrade_minor_version_enabled
      failure_suppression_enabled         = extension.value.failure_suppression_enabled
      force_extension_execution_on_change = extension.value.force_extension_execution_on_change
      settings                            = extension.value.settings
      protected_settings                  = extension.value.protected_settings

      dynamic "protected_settings_from_key_vault" {
        for_each = extension.value.protected_settings_from_key_vault != null ? [
          extension.value.protected_settings_from_key_vault
        ] : []
        content {
          secret_url      = protected_settings_from_key_vault.value.secret_url
          source_vault_id = protected_settings_from_key_vault.value.source_vault_id
        }
      }

    }
  }

  dynamic "boot_diagnostics" {
    for_each = each.value.boot_diagnostics != null ? [
      each.value.boot_diagnostics
    ] : []
    content {
      storage_account_uri = boot_diagnostics.value.storage_account_uri
    }
  }

  dynamic "additional_capabilities" {
    for_each = each.value.additional_capabilities != null && each.value.additional_capabilities != {} ? [
      each.value.additional_capabilities
    ] : []
    content {
      ultra_ssd_enabled = additional_capabilities.value.ultra_ssd_enabled
    }
  }

  dynamic "network_interface" {
    for_each = each.value.network_interface != null && each.value.network_interface != {} ? toset(each.value.network_interface) : []
    content {
      name                          = network_interface.value.name
      primary                       = network_interface.value.primary
      network_security_group_id     = network_interface.value.network_security_group_id
      enable_accelerated_networking = network_interface.value.enable_accelerated_networking
      enable_ip_forwarding          = network_interface.value.enable_ip_forwarding
      dns_servers                   = tolist(network_interface.value.dns_servers)

      dynamic "ip_configuration" {
        for_each = network_interface.value.ip_configuration != null && network_interface.value.ip_configuration != {} ? toset(network_interface.value.ip_configuration) : []
        content {
          name                                         = ip_configuration.value.name
          primary                                      = ip_configuration.value.primary
          application_gateway_backend_address_pool_ids = ip_configuration.value.application_gateway_backend_address_pool_ids
          application_security_group_ids = each.value.create_asg ? (
            ip_configuration.value.application_security_group_ids != null ?
            distinct(concat(ip_configuration.value.application_security_group_ids, [
              azurerm_application_security_group.asg[each.key].id
            ])) :
            [azurerm_application_security_group.asg[each.key].id]
          ) : []
          version   = ip_configuration.value.version
          subnet_id = ip_configuration.value.subnet_id

          dynamic "public_ip_address" {
            for_each = ip_configuration.value.public_ip_address != null && ip_configuration.value.public_ip_address != {} ? [
              ip_configuration.value.public_ip_address
            ] : []
            content {
              name                    = public_ip_address.value.name
              domain_name_label       = public_ip_address.value.domain_name_label
              idle_timeout_in_minutes = public_ip_address.value.idle_timeout_in_minutes
              public_ip_prefix_id     = public_ip_address.value.public_ip_prefix_id

              dynamic "ip_tag" {
                for_each = public_ip_address.value.ip_tag != null && public_ip_address.value.ip_tag != {} ? [
                  public_ip_address.value.ip_tag
                ] : []
                content {
                  type = ip_tag.value.type
                  tag  = ip_tag.value.tag
                }
              }
            }
          }
        }
      }
    }
  }

  dynamic "source_image_reference" {
    for_each = try(each.value.use_simple_image, null) == true && try(each.value.use_simple_image_with_plan, null) == false && try(each.value.use_custom_image, null) == false ? [
      1
    ] : []
    content {
      publisher = coalesce(each.value.vm_os_publisher, module.os_calculator[each.value.name].calculated_value_os_publisher)
      offer     = coalesce(each.value.vm_os_offer, module.os_calculator[each.value.name].calculated_value_os_offer)
      sku       = coalesce(each.value.vm_os_sku, module.os_calculator[each.value.name].calculated_value_os_sku)
      version   = coalesce(each.value.vm_os_version, "latest")
    }
  }


  # Use custom image reference
  dynamic "source_image_reference" {
    for_each = try(each.value.use_simple_image, null) == false && try(each.value.use_simple_image_with_plan, null) == false && try(length(each.value.source_image_reference), 0) > 0 && try(length(each.value.plan), 0) == 0 && try(each.value.use_custom_image, null) == false ? [
      1
    ] : []

    content {
      publisher = lookup(each.value.source_image_reference, "publisher", null)
      offer     = lookup(each.value.source_image_reference, "offer", null)
      sku       = lookup(each.value.source_image_reference, "sku", null)
      version   = lookup(each.value.source_image_reference, "version", null)
    }
  }

  dynamic "source_image_reference" {
    for_each = try(each.value.use_simple_image, null) == true && try(each.value.use_simple_image_with_plan, null) == true && try(each.value.use_custom_image, null) == false ? [
      1
    ] : []

    content {
      publisher = coalesce(each.value.vm_os_publisher, module.os_calculator_with_plan[each.value.name].calculated_value_os_publisher)
      offer     = coalesce(each.value.vm_os_offer, module.os_calculator_with_plan[each.value.name].calculated_value_os_offer)
      sku       = coalesce(each.value.vm_os_sku, module.os_calculator_with_plan[each.value.name].calculated_value_os_sku)
      version   = coalesce(each.value.vm_os_version, "latest")
    }
  }


  dynamic "plan" {
    for_each = try(each.value.use_simple_image, null) == false && try(each.value.use_simple_image_with_plan, null) == false && try(length(each.value.plan), 0) > 0 && try(each.value.use_custom_image, null) == false ? [
      1
    ] : []

    content {
      name      = coalesce(each.value.vm_os_sku, module.os_calculator_with_plan[each.value.name].calculated_value_os_sku)
      product   = coalesce(each.value.vm_os_offer, module.os_calculator_with_plan[each.value.name].calculated_value_os_offer)
      publisher = coalesce(each.value.vm_os_publisher, module.os_calculator_with_plan[each.value.name].calculated_value_os_publisher)
    }
  }


  dynamic "plan" {
    for_each = try(each.value.use_simple_image, null) == false && try(each.value.use_simple_image_with_plan, null) == false && try(length(each.value.plan), 0) > 0 && try(each.value.use_custom_image, null) == false ? [
      1
    ] : []

    content {
      name      = lookup(each.value.plan, "name", null)
      product   = lookup(each.value.plan, "product", null)
      publisher = lookup(each.value.plan, "publisher", null)
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = length(try(each.value.identity_ids, [])) > 0 ? each.value.identity_ids : []
    }
  }
}

module "os_calculator" {
  source       = "libre-devops/vm-os-sku-calculator/azurerm"
  for_each     = { for vm in var.scale_sets : vm.name => vm if try(vm.use_simple_image, null) == true }
  vm_os_simple = each.value.vm_os_simple
}

module "os_calculator_with_plan" {
  source       = "libre-devops/vm-os-sku-with-plan-calculator/azurerm"
  for_each     = { for vm in var.scale_sets : vm.name => vm if try(vm.use_simple_image_with_plan, null) == true }
  vm_os_simple = each.value.vm_os_simple
}

resource "azurerm_marketplace_agreement" "plan_acceptance_simple" {
  for_each = {
    for vm in var.scale_sets : vm.name => vm
    if try(vm.use_simple_image_with_plan, null) == true && try(vm.accept_plan, null) == true && try(vm.use_custom_image, null) == false
  }

  publisher = coalesce(each.value.vm_os_publisher, module.os_calculator_with_plan[each.key].calculated_value_os_publisher)
  offer     = coalesce(each.value.vm_os_offer, module.os_calculator_with_plan[each.key].calculated_value_os_offer)
  plan      = coalesce(each.value.vm_os_sku, module.os_calculator_with_plan[each.key].calculated_value_os_sku)
}

resource "azurerm_marketplace_agreement" "plan_acceptance_custom" {
  for_each = {
    for vm in var.scale_sets : vm.name => vm
    if try(vm.use_custom_image_with_plan, null) == true && try(vm.accept_plan, null) == true && try(vm.use_custom_image, null) == true
  }

  publisher = lookup(each.value.plan, "publisher", null)
  offer     = lookup(each.value.plan, "product", null)
  plan      = lookup(each.value.plan, "name", null)
}

resource "azurerm_application_security_group" "asg" {
  for_each = { for vm in var.scale_sets : vm.name => vm if vm.create_asg == true }

  name                = each.value.asg_name != null ? each.value.asg_name : "asg-${each.value.name}"
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags
}
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_os_calculator"></a> [os\_calculator](#module\_os\_calculator) | libre-devops/vm-os-sku-calculator/azurerm | n/a |
| <a name="module_os_calculator_with_plan"></a> [os\_calculator\_with\_plan](#module\_os\_calculator\_with\_plan) | libre-devops/vm-os-sku-with-plan-calculator/azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_application_security_group.asg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_security_group) | resource |
| [azurerm_marketplace_agreement.plan_acceptance_custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/marketplace_agreement) | resource |
| [azurerm_marketplace_agreement.plan_acceptance_simple](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/marketplace_agreement) | resource |
| [azurerm_orchestrated_virtual_machine_scale_set.scale_set](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/orchestrated_virtual_machine_scale_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | The region to place the resources | `string` | n/a | yes |
| <a name="input_rg_name"></a> [rg\_name](#input\_rg\_name) | The resource group name to place the scale sets in | `string` | n/a | yes |
| <a name="input_scale_sets"></a> [scale\_sets](#input\_scale\_sets) | The scale sets list of object variable | <pre>list(object({<br>    name                         = string<br>    platform_fault_domain_count  = number<br>    sku                          = optional(string)<br>    computer_name_prefix         = optional(string)<br>    create_asg                   = optional(bool, false)<br>    asg_name                     = optional(string)<br>    use_custom_image             = optional(bool, false)<br>    use_custom_image_with_plan   = optional(bool, false)<br>    use_simple_image             = optional(bool, true)<br>    use_simple_image_with_plan   = optional(bool, false)<br>    vm_os_id                     = optional(string, "")<br>    vm_os_offer                  = optional(string)<br>    vm_os_publisher              = optional(string)<br>    vm_os_simple                 = optional(string)<br>    vm_os_sku                    = optional(string)<br>    vm_os_version                = optional(string)<br>    max_bid_price                = optional(string)<br>    priority                     = optional(string)<br>    user_data_base64             = optional(string)<br>    proximity_placement_group_id = optional(string)<br>    zone_balance                 = optional(bool)<br>    zones                        = optional(list(string))<br>    priority_mix = optional(object({<br>      base_regular_count            = optional(number)<br>      regular_percentage_above_base = optional(number)<br>    }))<br>    single_placement_group = optional(bool)<br>    termination_notification = optional(object({<br>      enabled = optional(bool)<br>      timeout = optional(string)<br>    }))<br>    source_image_reference = optional(object({<br>      publisher = optional(string)<br>      offer     = optional(string)<br>      sku       = optional(string)<br>      version   = optional(string)<br>    }))<br>    additional_capabilities = optional(object({<br>      ultra_ssd_enabled = optional(bool)<br>    }))<br>    encryption_at_host_enabled = optional(bool)<br>    automatic_instance_repair = optional(object({<br>      enabled      = optional(bool)<br>      grace_period = optional(string)<br>    }))<br>    instances = optional(number)<br>    boot_diagnostics = optional(object({<br>      storage_account_uri = optional(string)<br>    }))<br>    capacity_reservation_group_id = optional(string)<br>    extension_operations_enabled  = optional(bool)<br>    identity_type                 = optional(string)<br>    identity_ids                  = optional(list(string))<br>    extensions_time_budget        = optional(string)<br>    eviction_policy               = optional(string)<br>    license_type                  = optional(string)<br>    plan = optional(object({<br>      name      = optional(string)<br>      product   = optional(string)<br>      publisher = optional(string)<br>    }))<br>    extension = optional(list(object({<br>      name                                      = string<br>      publisher                                 = string<br>      type                                      = string<br>      type_handler_version                      = string<br>      auto_upgrade_minor_version_enabled        = optional(bool)<br>      failure_suppression_enabled               = optional(bool)<br>      force_extension_execution_on_change       = optional(string)<br>      extensions_to_provision_after_vm_creation = optional(list(string))<br>      settings                                  = optional(string)<br>      protected_settings                        = optional(string)<br>      protected_settings_from_key_vault = optional(object({<br>        secret_url      = optional(string)<br>        source_vault_id = optional(string)<br>      }))<br>    })))<br>    data_disk = optional(list(object({<br>      lun                            = optional(number)<br>      create_option                  = optional(string)<br>      caching                        = string<br>      storage_account_type           = optional(string)<br>      disk_size_gb                   = optional(number)<br>      disk_encryption_set_id         = optional(string)<br>      ultra_ssd_disk_iops_read_write = optional(string)<br>      ultra_ssd_disk_mbps_read_write = optional(string)<br>      write_accelerator_enabled      = optional(bool)<br>    })))<br>    os_disk = object({<br>      caching                          = optional(string, "ReadWrite")<br>      storage_account_type             = optional(string)<br>      disk_size_gb                     = optional(number)<br>      disk_encryption_set_id           = optional(string)<br>      secure_vm_disk_encryption_set_id = optional(string)<br>      security_encryption_type         = optional(string)<br>      write_accelerator_enabled        = optional(bool)<br>      diff_disk_settings = optional(object({<br>        option    = string<br>        placement = optional(string)<br>      }))<br>    })<br>    os_profile = optional(object({<br>      custom_data = optional(string)<br>      windows_configuration = optional(object({<br>        admin_username           = string<br>        admin_password           = string<br>        computer_name_prefix     = optional(string)<br>        enable_automatic_updates = optional(bool)<br>        hotpatching_enabled      = optional(bool)<br>        patch_assessment_mode    = optional(string)<br>        patch_mode               = optional(string)<br>        provision_vm_agent       = optional(bool)<br>        timezone                 = optional(string)<br>        additional_unattend_content = optional(list(object({<br>          content = string<br>          setting = string<br>        })))<br>        winrm_listener = optional(list(object({<br>          protocol        = string<br>          certificate_url = optional(string)<br>        })))<br>        secret = optional(list(object({<br>          key_vault_id = string<br>          certificate = list(object({<br>            store = string<br>            url   = string<br>          }))<br>        })))<br>      }))<br>      linux_configuration = optional(object({<br>        admin_username                  = string<br>        admin_password                  = optional(string)<br>        computer_name_prefix            = optional(string)<br>        disable_password_authentication = optional(bool)<br>        patch_assessment_mode           = optional(string)<br>        patch_mode                      = optional(string)<br>        provision_vm_agent              = optional(bool)<br>        secret = optional(list(object({<br>          key_vault_id = string<br>          certificate = list(object({<br>            store = string<br>            url   = string<br>          }))<br>        })))<br>        admin_ssh_key = optional(object({<br>          public_key = optional(string)<br>          username   = optional(string)<br>        }))<br>      }))<br>    }))<br>    network_interface = optional(list(object({<br>      name                          = optional(string)<br>      primary                       = optional(bool)<br>      network_security_group_id     = optional(string)<br>      enable_accelerated_networking = optional(bool)<br>      enable_ip_forwarding          = optional(bool)<br>      dns_servers                   = optional(list(string))<br>      ip_configuration = optional(list(object({<br>        name                                         = optional(string)<br>        primary                                      = optional(bool)<br>        application_gateway_backend_address_pool_ids = optional(list(string))<br>        application_security_group_ids               = optional(list(string))<br>        version                                      = optional(string)<br>        subnet_id                                    = optional(string)<br>        public_ip_address = optional(object({<br>          name                    = optional(string)<br>          domain_name_label       = optional(string)<br>          idle_timeout_in_minutes = optional(number)<br>          public_ip_prefix_id     = optional(string)<br>          ip_tag = optional(list(object({<br>            type = optional(string)<br>            tag  = optional(string)<br>          })))<br>        }))<br>      })))<br>    })))<br>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to be applied to the resource | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ss_id"></a> [ss\_id](#output\_ss\_id) | The name of the scale set |
| <a name="output_ss_identity"></a> [ss\_identity](#output\_ss\_identity) | The identity block of the scale set |
| <a name="output_ss_name"></a> [ss\_name](#output\_ss\_name) | The name of the scale set |
| <a name="output_unique_ss_id"></a> [unique\_ss\_id](#output\_unique\_ss\_id) | The id of the scale set |
