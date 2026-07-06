variable "location" {
  description = "Azure region for the scale sets."
  type        = string
}

variable "resource_group_id" {
  description = "Resource id of the resource group the scale sets are created in. The resource group name and subscription are parsed from this id."
  type        = string

  validation {
    condition     = try(provider::azurerm::parse_resource_id(var.resource_group_id).resource_type, "") == "resourceGroups"
    error_message = "resource_group_id must be a resource group resource id."
  }
}

variable "scale_sets" {
  description = <<-EOT
    Flexible-orchestration virtual machine scale sets keyed by name (vmssldouksprd001, the no-dash
    convention). Each entry is Linux or Windows by which os_profile configuration it sets. Highlights:
      sku_name / sku_profile   Exactly one: a single size (Standard_B2als_v2) or a mixed-size
                               profile (allocation_strategy plus ranked virtual_machine_sizes;
                               sku_name becomes Mix automatically).
      platform_fault_domain_count  Defaults to 1 (max spreading, the recommended flexible value).
      zones                    Zone-redundant ["1", "2", "3"] by default; set [] for regions
                               without zones.
      os_profile               linux { admin_username, admin_ssh_keys, ... } or windows
                               { admin_username, admin_password, ... }. Linux is SSH-only by
                               default (disable_password_authentication = true).
      source_image_simple      A catalog key (see image_catalog_keys output); or
                               source_image_reference / source_image_id. Catalog plans (Rocky)
                               flow through; accept_marketplace_agreement = true accepts the terms
                               on first use.
      network_interfaces       Map keyed by NIC name; each carries ip_configurations keyed by
                               name (subnet_id plus optional load balancer / application gateway
                               backend pools, ASGs, and an inline public ip per instance). Single
                               NIC and single ip configuration are marked primary automatically.
      priority                 Regular (default) or Spot (with eviction_policy, max_bid_price,
                               and priority_mix for mixing Spot and Regular instances).
      user_data                Plain text, base64-encoded by the module.
    Rolling upgrades (rolling_upgrade_policy) require upgrade_mode = "Rolling"; automatic instance
    repair needs an application health extension deployed.
  EOT
  type = map(object({
    sku_name  = optional(string)
    instances = optional(number)
    sku_profile = optional(object({
      allocation_strategy = optional(string, "LowestPrice")
      virtual_machine_sizes = list(object({
        name = string
        rank = optional(number)
      }))
    }))

    platform_fault_domain_count = optional(number, 1)
    zones                       = optional(set(string), ["1", "2", "3"])
    zone_balance                = optional(bool)
    single_placement_group      = optional(bool)
    tags                        = optional(map(string))

    os_profile = object({
      custom_data = optional(string)
      linux = optional(object({
        admin_username = string
        admin_ssh_keys = optional(list(object({
          public_key = string
          username   = optional(string)
        })), [])
        admin_password                  = optional(string)
        disable_password_authentication = optional(bool, true)
        computer_name_prefix            = optional(string)
        patch_mode                      = optional(string)
        patch_assessment_mode           = optional(string)
        provision_vm_agent              = optional(bool, true)
        secrets = optional(list(object({
          key_vault_id     = string
          certificate_urls = list(string)
        })), [])
      }))
      windows = optional(object({
        admin_username           = string
        admin_password           = string
        computer_name_prefix     = optional(string)
        enable_automatic_updates = optional(bool, true)
        hotpatching_enabled      = optional(bool)
        patch_mode               = optional(string)
        patch_assessment_mode    = optional(string)
        provision_vm_agent       = optional(bool, true)
        timezone                 = optional(string)
        additional_unattend_content = optional(list(object({
          content = string
          setting = string
        })), [])
        winrm_listeners = optional(list(object({
          protocol        = string
          certificate_url = optional(string)
        })), [])
        secrets = optional(list(object({
          key_vault_id = string
          certificates = list(object({
            store = string
            url   = string
          }))
        })), [])
      }))
    })

    source_image_simple = optional(string)
    source_image_id     = optional(string)
    source_image_reference = optional(object({
      publisher = string
      offer     = string
      sku       = string
      version   = optional(string, "latest")
    }))
    plan = optional(object({
      name      = string
      product   = string
      publisher = string
    }))
    accept_marketplace_agreement = optional(bool, false)

    os_disk = optional(object({
      caching                   = optional(string, "ReadWrite")
      storage_account_type      = optional(string, "StandardSSD_LRS")
      disk_size_gb              = optional(number)
      disk_encryption_set_id    = optional(string)
      write_accelerator_enabled = optional(bool, false)
      diff_disk_settings = optional(object({
        option    = string
        placement = optional(string)
      }))
    }), {})

    data_disks = optional(list(object({
      caching                        = optional(string, "ReadWrite")
      storage_account_type           = optional(string, "StandardSSD_LRS")
      disk_size_gb                   = optional(number)
      lun                            = optional(number)
      create_option                  = optional(string)
      disk_encryption_set_id         = optional(string)
      ultra_ssd_disk_iops_read_write = optional(number)
      ultra_ssd_disk_mbps_read_write = optional(number)
      write_accelerator_enabled      = optional(bool)
    })), [])

    network_interfaces = map(object({
      primary                        = optional(bool)
      accelerated_networking_enabled = optional(bool, false)
      ip_forwarding_enabled          = optional(bool, false)
      dns_servers                    = optional(list(string))
      network_security_group_id      = optional(string)
      auxiliary_mode                 = optional(string)
      auxiliary_sku                  = optional(string)
      ip_configurations = map(object({
        subnet_id                                    = string
        primary                                      = optional(bool)
        version                                      = optional(string)
        load_balancer_backend_address_pool_ids       = optional(set(string))
        application_gateway_backend_address_pool_ids = optional(set(string))
        application_security_group_ids               = optional(set(string))
        public_ip_address = optional(object({
          name                    = string
          domain_name_label       = optional(string)
          idle_timeout_in_minutes = optional(number)
          public_ip_prefix_id     = optional(string)
          sku_name                = optional(string)
          version                 = optional(string)
          ip_tags = optional(list(object({
            tag  = string
            type = string
          })), [])
        }))
      }))
    }))

    extensions = optional(map(object({
      publisher                                 = string
      type                                      = string
      type_handler_version                      = string
      auto_upgrade_minor_version_enabled        = optional(bool, true)
      settings                                  = optional(string)
      protected_settings                        = optional(string)
      extensions_to_provision_after_vm_creation = optional(list(string))
      failure_suppression_enabled               = optional(bool)
      force_extension_execution_on_change       = optional(string)
      protected_settings_from_key_vault = optional(object({
        secret_url      = string
        source_vault_id = string
      }))
    })), {})

    identity = optional(object({
      type         = optional(string, "UserAssigned")
      identity_ids = set(string)
    }))

    boot_diagnostics = optional(object({
      enabled             = optional(bool, true)
      storage_account_uri = optional(string)
    }), {})

    priority        = optional(string, "Regular")
    eviction_policy = optional(string)
    max_bid_price   = optional(number)
    priority_mix = optional(object({
      base_regular_count            = optional(number)
      regular_percentage_above_base = optional(number)
    }))

    upgrade_mode = optional(string)
    rolling_upgrade_policy = optional(object({
      max_batch_instance_percent              = optional(number, 20)
      max_unhealthy_instance_percent          = optional(number, 20)
      max_unhealthy_upgraded_instance_percent = optional(number, 20)
      pause_time_between_batches              = optional(string, "PT30S")
      cross_zone_upgrades_enabled             = optional(bool)
      maximum_surge_instances_enabled         = optional(bool)
      prioritize_unhealthy_instances_enabled  = optional(bool)
    }))

    automatic_instance_repair = optional(object({
      enabled      = bool
      grace_period = optional(string)
      action       = optional(string)
    }))

    termination_notification = optional(object({
      enabled = bool
      timeout = optional(string)
    }))

    user_data                     = optional(string)
    ultra_ssd_enabled             = optional(bool)
    capacity_reservation_group_id = optional(string)
    proximity_placement_group_id  = optional(string)
    license_type                  = optional(string)
    encryption_at_host_enabled    = optional(bool)
    extension_operations_enabled  = optional(bool)
    extensions_time_budget        = optional(string)
    network_api_version           = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.scale_sets) :
      (s.os_profile.linux != null && s.os_profile.windows == null) || (s.os_profile.linux == null && s.os_profile.windows != null)
    ])
    error_message = "every scale set sets exactly one of os_profile.linux or os_profile.windows."
  }

  validation {
    condition = alltrue([
      for s in values(var.scale_sets) :
      length([for v in [s.source_image_simple, s.source_image_id, s.source_image_reference] : v if v != null]) == 1
    ])
    error_message = "every scale set sets exactly one image source: source_image_simple, source_image_reference, or source_image_id."
  }

  validation {
    condition = alltrue([
      for s in values(var.scale_sets) :
      (s.sku_name != null && s.sku_profile == null) || (s.sku_name == null && s.sku_profile != null)
    ])
    error_message = "every scale set sets exactly one of sku_name or sku_profile (mixed sizes)."
  }

  validation {
    condition = alltrue([
      for s in values(var.scale_sets) :
      s.priority == "Spot" || (s.eviction_policy == null && s.max_bid_price == null && s.priority_mix == null)
    ])
    error_message = "eviction_policy, max_bid_price, and priority_mix only apply to Spot scale sets (priority = \"Spot\")."
  }

  validation {
    condition     = alltrue([for s in values(var.scale_sets) : s.rolling_upgrade_policy == null || s.upgrade_mode == "Rolling"])
    error_message = "rolling_upgrade_policy requires upgrade_mode = \"Rolling\"."
  }

  validation {
    condition     = alltrue([for s in values(var.scale_sets) : length(s.network_interfaces) > 0])
    error_message = "every scale set needs at least one network interface."
  }

  validation {
    condition = alltrue([
      for s in values(var.scale_sets) :
      length(s.network_interfaces) == 1 || length([for n in values(s.network_interfaces) : n if coalesce(n.primary, false)]) == 1
    ])
    error_message = "with more than one network interface, exactly one must set primary = true (a single interface is primary automatically)."
  }

  validation {
    condition = alltrue(flatten([
      for s in values(var.scale_sets) : [
        for n in values(s.network_interfaces) :
        length(n.ip_configurations) == 1 || length([for c in values(n.ip_configurations) : c if coalesce(c.primary, false)]) == 1
      ]
    ]))
    error_message = "with more than one ip configuration on an interface, exactly one must set primary = true (a single configuration is primary automatically)."
  }

  validation {
    condition = alltrue([
      for s in values(var.scale_sets) :
      s.os_profile.linux == null ? true : (
        coalesce(s.os_profile.linux.disable_password_authentication, true)
        ? length(s.os_profile.linux.admin_ssh_keys) > 0
        : s.os_profile.linux.admin_password != null
      )
    ])
    error_message = "a Linux scale set needs admin_ssh_keys (SSH-only default), or an admin_password when disable_password_authentication = false."
  }

  validation {
    # try() guards the null side: 1.9 evaluates both || operands.
    condition     = alltrue([for s in values(var.scale_sets) : contains(["UserAssigned"], try(s.identity.type, "UserAssigned"))])
    error_message = "orchestrated scale sets only support UserAssigned identities."
  }
}

variable "tags" {
  description = "Tags applied to the scale sets (merged with per-scale-set tags)."
  type        = map(string)
  default     = {}
}
