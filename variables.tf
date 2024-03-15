variable "location" {
  type        = string
  description = "The region to place the resources"
}

variable "rg_name" {
  type        = string
  description = "The resource group name to place the scale sets in"
}

variable "scale_sets" {
  description = "The scale sets list of object variable"
  type = list(object({
    name                         = string
    platform_fault_domain_count  = number
    sku                          = optional(string)
    computer_name_prefix         = optional(string)
    create_asg                   = optional(bool, false)
    asg_name                     = optional(string)
    use_custom_image             = optional(bool, false)
    use_custom_image_with_plan   = optional(bool, false)
    use_simple_image             = optional(bool, true)
    use_simple_image_with_plan   = optional(bool, false)
    vm_os_id                     = optional(string, "")
    vm_os_offer                  = optional(string)
    vm_os_publisher              = optional(string)
    vm_os_simple                 = optional(string)
    vm_os_sku                    = optional(string)
    vm_os_version                = optional(string)
    max_bid_price                = optional(string)
    priority                     = optional(string)
    user_data_base64             = optional(string)
    proximity_placement_group_id = optional(string)
    zone_balance                 = optional(bool, true)
    zones                        = optional(list(string))
    priority_mix = optional(object({
      base_regular_count            = optional(number)
      regular_percentage_above_base = optional(number)
    }))
    single_placement_group = optional(bool)
    termination_notification = optional(object({
      enabled = optional(bool)
      timeout = optional(string)
    }))
    source_image_reference = optional(object({
      publisher = optional(string)
      offer     = optional(string)
      sku       = optional(string)
      version   = optional(string)
    }))
    additional_capabilities = optional(object({
      ultra_ssd_enabled = optional(bool)
    }))
    encryption_at_host_enabled = optional(bool)
    automatic_instance_repair = optional(object({
      enabled      = optional(bool)
      grace_period = optional(string)
    }))
    instances = optional(number)
    boot_diagnostics = optional(object({
      storage_account_uri = optional(string)
    }))
    capacity_reservation_group_id = optional(string)
    extension_operations_enabled  = optional(bool)
    identity_type                 = optional(string)
    identity_ids                  = optional(list(string))
    extensions_time_budget        = optional(string)
    eviction_policy               = optional(string)
    license_type                  = optional(string)
    plan = optional(object({
      name      = optional(string)
      product   = optional(string)
      publisher = optional(string)
    }))
    extension = optional(list(object({
      name                                      = string
      publisher                                 = string
      type                                      = string
      type_handler_version                      = string
      auto_upgrade_minor_version_enabled        = optional(bool)
      failure_suppression_enabled               = optional(bool)
      force_extension_execution_on_change       = optional(string)
      extensions_to_provision_after_vm_creation = optional(list(string))
      settings                                  = optional(string)
      protected_settings                        = optional(string)
      protected_settings_from_key_vault = optional(object({
        secret_url      = optional(string)
        source_vault_id = optional(string)
      }))
    })))
    data_disk = optional(list(object({
      lun                            = optional(number)
      create_option                  = optional(string)
      caching                        = string
      storage_account_type           = optional(string)
      disk_size_gb                   = optional(number)
      disk_encryption_set_id         = optional(string)
      ultra_ssd_disk_iops_read_write = optional(string)
      ultra_ssd_disk_mbps_read_write = optional(string)
      write_accelerator_enabled      = optional(bool)
    })))
    os_disk = object({
      caching                          = optional(string, "ReadWrite")
      storage_account_type             = optional(string)
      disk_size_gb                     = optional(number)
      disk_encryption_set_id           = optional(string)
      secure_vm_disk_encryption_set_id = optional(string)
      security_encryption_type         = optional(string)
      write_accelerator_enabled        = optional(bool)
      diff_disk_settings = optional(object({
        option    = string
        placement = optional(string)
      }))
    })
    os_profile = optional(object({
      custom_data = optional(string)
      windows_configuration = optional(object({
        admin_username           = string
        admin_password           = string
        computer_name_prefix     = optional(string)
        enable_automatic_updates = optional(bool)
        hotpatching_enabled      = optional(bool)
        patch_assessment_mode    = optional(string)
        patch_mode               = optional(string)
        provision_vm_agent       = optional(bool)
        timezone                 = optional(string)
        additional_unattend_content = optional(list(object({
          content = string
          setting = string
        })))
        winrm_listener = optional(list(object({
          protocol        = string
          certificate_url = optional(string)
        })))
        secret = optional(list(object({
          key_vault_id = string
          certificate = list(object({
            store = string
            url   = string
          }))
        })))
      }))
      linux_configuration = optional(object({
        admin_username                  = string
        admin_password                  = optional(string)
        computer_name_prefix            = optional(string)
        disable_password_authentication = optional(bool)
        patch_assessment_mode           = optional(string)
        patch_mode                      = optional(string)
        provision_vm_agent              = optional(bool)
        secret = optional(list(object({
          key_vault_id = string
          certificate = list(object({
            store = string
            url   = string
          }))
        })))
        admin_ssh_key = optional(object({
          public_key = optional(string)
          username   = optional(string)
        }))
      }))
    }))
    network_interface = optional(list(object({
      name                          = optional(string)
      primary                       = optional(bool)
      network_security_group_id     = optional(string)
      enable_accelerated_networking = optional(bool)
      enable_ip_forwarding          = optional(bool)
      dns_servers                   = optional(list(string))
      ip_configuration = optional(list(object({
        name                                         = optional(string)
        primary                                      = optional(bool)
        application_gateway_backend_address_pool_ids = optional(list(string))
        application_security_group_ids               = optional(list(string))
        version                                      = optional(string)
        subnet_id                                    = optional(string)
        public_ip_address = optional(object({
          name                    = optional(string)
          domain_name_label       = optional(string)
          idle_timeout_in_minutes = optional(number)
          public_ip_prefix_id     = optional(string)
          ip_tag = optional(list(object({
            type = optional(string)
            tag  = optional(string)
          })))
        }))
      })))
    })))
  }))
}

variable "tags" {
  type        = map(string)
  description = "Tags to be applied to the resource"
}
