<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Flexible Orchestration VM Scale Sets

Flexible-orchestration virtual machine scale sets, Linux or Windows per entry, with the image
catalog, Spot capacity, mixed-size sku profiles, and rolling upgrades first-class.

[![CI](https://github.com/libre-devops/terraform-azurerm-flexible-orchestration-vm-scale-sets/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-flexible-orchestration-vm-scale-sets/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-flexible-orchestration-vm-scale-sets?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-flexible-orchestration-vm-scale-sets/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-flexible-orchestration-vm-scale-sets)](./LICENSE)

---

## Overview

Flexible-orchestration scale sets (`azurerm_orchestrated_virtual_machine_scale_set`) keyed by name.
Each entry is Linux or Windows by which `os_profile` configuration it sets; for the uniform
orchestration mode use the
[`uniform-linux`](https://github.com/libre-devops/terraform-azurerm-linux-uniform-orchestration-vm-scale-set)
/ [`uniform-windows`](https://github.com/libre-devops/terraform-azurerm-windows-uniform-orchestration-vm-scale-sets)
siblings.

What the module adds over the bare resource:

- **Sensible secure defaults**: SSH-only Linux (password auth is an explicit, checked opt-out),
  zone-redundant with `platform_fault_domain_count = 1` (max spreading, the recommended flexible
  value), and managed boot diagnostics.
- **The image catalog**: `source_image_simple = "Ubuntu2404"` instead of a
  publisher/offer/sku hunt, marketplace-verified entries for both OSes, with plans (Rocky) flowing
  into the `plan` block and `accept_marketplace_agreement` handling the terms, deduplicated across
  scale sets. `source_image_reference` and `source_image_id` remain first-class.
- **Ergonomics with full coverage**: single NIC and single ip configuration are primary
  automatically; `user_data` is base64-encoded for you; a mixed-size `sku_profile` forces
  `sku_name = "Mix"` as Azure demands. Spot (with `priority_mix`), rolling upgrades, automatic
  instance repair, extensions, Key Vault secrets, and private-link-era NIC options are all exposed.
- **Plan-time truth**: exactly one OS configuration, exactly one image source, `sku_name` XOR
  `sku_profile`, Spot-only fields on Spot, SSH keys on SSH-only Linux, and unambiguous primary
  NICs are all validated; `check` blocks flag password-auth opt-ins and instance repair without an
  Application Health extension.

The resource group is passed by id and parsed. Note the orchestrated resource does not expose
Trusted Launch settings in the current provider; the uniform siblings default secure boot and vTPM
on.

## Usage

```hcl
module "flex_vmss" {
  source  = "libre-devops/flexible-orchestration-vm-scale-sets/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-prd-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  scale_sets = {
    "vmssldouksprd001" = {
      sku_name  = "Standard_D2lds_v6"
      instances = 2

      source_image_simple = "Ubuntu2404"

      os_profile = {
        linux = {
          admin_username = "azureuser"
          admin_ssh_keys = [{ public_key = var.admin_public_key }]
        }
      }

      network_interfaces = {
        "nic" = {
          ip_configurations = {
            "internal" = {
              subnet_id                              = module.network.subnet_ids["snet-app-vnet-ldo-uks-prd-001"]
              load_balancer_backend_address_pool_ids = [module.private_lb.backend_pool_ids["lbi-ldo-uks-prd-001/app"]]
            }
          }
        }
      }
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - one Linux scale set, one instance, catalog image,
  module defaults.
- [`examples/complete`](./examples/complete) - a Linux set on a private load balancer pool with an
  Application Health extension, automatic instance repair, termination notification, a data disk,
  and user_data, plus a Windows set. Spot and mixed-size sku profiles are covered by the mocked
  tests (legal to apply, hostage to capacity in a short-lived E2E).

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in the table
below so the reason is auditable.

| Trivy ID | Resource | Finding | Justification |
|----------|----------|---------|---------------|
| _None_   |          |         |               |

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here. Where the finding is out of this module's
scope, point the justification at the Libre DevOps module that does address it (for example the
private-endpoint module). Both the file and this table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_marketplace_agreement.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/marketplace_agreement) | resource |
| [azurerm_orchestrated_virtual_machine_scale_set.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/orchestrated_virtual_machine_scale_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | Azure region for the scale sets. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Resource id of the resource group the scale sets are created in. The resource group name and subscription are parsed from this id. | `string` | n/a | yes |
| <a name="input_scale_sets"></a> [scale\_sets](#input\_scale\_sets) | Flexible-orchestration virtual machine scale sets keyed by name (vmssldouksprd001, the no-dash<br/>convention). Each entry is Linux or Windows by which os\_profile configuration it sets. Highlights:<br/>  sku\_name / sku\_profile   Exactly one: a single size (Standard\_B2als\_v2) or a mixed-size<br/>                           profile (allocation\_strategy plus ranked virtual\_machine\_sizes;<br/>                           sku\_name becomes Mix automatically).<br/>  platform\_fault\_domain\_count  Defaults to 1 (max spreading, the recommended flexible value).<br/>  zones                    Zone-redundant ["1", "2", "3"] by default; set [] for regions<br/>                           without zones.<br/>  os\_profile               linux { admin\_username, admin\_ssh\_keys, ... } or windows<br/>                           { admin\_username, admin\_password, ... }. Linux is SSH-only by<br/>                           default (disable\_password\_authentication = true).<br/>  source\_image\_simple      A catalog key (see image\_catalog\_keys output); or<br/>                           source\_image\_reference / source\_image\_id. Catalog plans (Rocky)<br/>                           flow through; accept\_marketplace\_agreement = true accepts the terms<br/>                           on first use.<br/>  network\_interfaces       Map keyed by NIC name; each carries ip\_configurations keyed by<br/>                           name (subnet\_id plus optional load balancer / application gateway<br/>                           backend pools, ASGs, and an inline public ip per instance). Single<br/>                           NIC and single ip configuration are marked primary automatically.<br/>  priority                 Regular (default) or Spot (with eviction\_policy, max\_bid\_price,<br/>                           and priority\_mix for mixing Spot and Regular instances).<br/>  user\_data                Plain text, base64-encoded by the module.<br/>Rolling upgrades (rolling\_upgrade\_policy) require upgrade\_mode = "Rolling"; automatic instance<br/>repair needs an application health extension deployed. | <pre>map(object({<br/>    sku_name  = optional(string)<br/>    instances = optional(number)<br/>    sku_profile = optional(object({<br/>      allocation_strategy = optional(string, "LowestPrice")<br/>      virtual_machine_sizes = list(object({<br/>        name = string<br/>        rank = optional(number)<br/>      }))<br/>    }))<br/><br/>    platform_fault_domain_count = optional(number, 1)<br/>    zones                       = optional(set(string), ["1", "2", "3"])<br/>    zone_balance                = optional(bool)<br/>    single_placement_group      = optional(bool)<br/>    tags                        = optional(map(string))<br/><br/>    os_profile = object({<br/>      custom_data = optional(string)<br/>      linux = optional(object({<br/>        admin_username = string<br/>        admin_ssh_keys = optional(list(object({<br/>          public_key = string<br/>          username   = optional(string)<br/>        })), [])<br/>        admin_password                  = optional(string)<br/>        disable_password_authentication = optional(bool, true)<br/>        computer_name_prefix            = optional(string)<br/>        patch_mode                      = optional(string)<br/>        patch_assessment_mode           = optional(string)<br/>        provision_vm_agent              = optional(bool, true)<br/>        secrets = optional(list(object({<br/>          key_vault_id     = string<br/>          certificate_urls = list(string)<br/>        })), [])<br/>      }))<br/>      windows = optional(object({<br/>        admin_username           = string<br/>        admin_password           = string<br/>        computer_name_prefix     = optional(string)<br/>        enable_automatic_updates = optional(bool, true)<br/>        hotpatching_enabled      = optional(bool)<br/>        patch_mode               = optional(string)<br/>        patch_assessment_mode    = optional(string)<br/>        provision_vm_agent       = optional(bool, true)<br/>        timezone                 = optional(string)<br/>        additional_unattend_content = optional(list(object({<br/>          content = string<br/>          setting = string<br/>        })), [])<br/>        winrm_listeners = optional(list(object({<br/>          protocol        = string<br/>          certificate_url = optional(string)<br/>        })), [])<br/>        secrets = optional(list(object({<br/>          key_vault_id = string<br/>          certificates = list(object({<br/>            store = string<br/>            url   = string<br/>          }))<br/>        })), [])<br/>      }))<br/>    })<br/><br/>    source_image_simple = optional(string)<br/>    source_image_id     = optional(string)<br/>    source_image_reference = optional(object({<br/>      publisher = string<br/>      offer     = string<br/>      sku       = string<br/>      version   = optional(string, "latest")<br/>    }))<br/>    plan = optional(object({<br/>      name      = string<br/>      product   = string<br/>      publisher = string<br/>    }))<br/>    accept_marketplace_agreement = optional(bool, false)<br/><br/>    os_disk = optional(object({<br/>      caching                   = optional(string, "ReadWrite")<br/>      storage_account_type      = optional(string, "StandardSSD_LRS")<br/>      disk_size_gb              = optional(number)<br/>      disk_encryption_set_id    = optional(string)<br/>      write_accelerator_enabled = optional(bool, false)<br/>      diff_disk_settings = optional(object({<br/>        option    = string<br/>        placement = optional(string)<br/>      }))<br/>    }), {})<br/><br/>    data_disks = optional(list(object({<br/>      caching                        = optional(string, "ReadWrite")<br/>      storage_account_type           = optional(string, "StandardSSD_LRS")<br/>      disk_size_gb                   = optional(number)<br/>      lun                            = optional(number)<br/>      create_option                  = optional(string)<br/>      disk_encryption_set_id         = optional(string)<br/>      ultra_ssd_disk_iops_read_write = optional(number)<br/>      ultra_ssd_disk_mbps_read_write = optional(number)<br/>      write_accelerator_enabled      = optional(bool)<br/>    })), [])<br/><br/>    network_interfaces = map(object({<br/>      primary                        = optional(bool)<br/>      accelerated_networking_enabled = optional(bool, false)<br/>      ip_forwarding_enabled          = optional(bool, false)<br/>      dns_servers                    = optional(list(string))<br/>      network_security_group_id      = optional(string)<br/>      auxiliary_mode                 = optional(string)<br/>      auxiliary_sku                  = optional(string)<br/>      ip_configurations = map(object({<br/>        subnet_id                                    = string<br/>        primary                                      = optional(bool)<br/>        version                                      = optional(string)<br/>        load_balancer_backend_address_pool_ids       = optional(set(string))<br/>        application_gateway_backend_address_pool_ids = optional(set(string))<br/>        application_security_group_ids               = optional(set(string))<br/>        public_ip_address = optional(object({<br/>          name                    = string<br/>          domain_name_label       = optional(string)<br/>          idle_timeout_in_minutes = optional(number)<br/>          public_ip_prefix_id     = optional(string)<br/>          sku_name                = optional(string)<br/>          version                 = optional(string)<br/>          ip_tags = optional(list(object({<br/>            tag  = string<br/>            type = string<br/>          })), [])<br/>        }))<br/>      }))<br/>    }))<br/><br/>    extensions = optional(map(object({<br/>      publisher                                 = string<br/>      type                                      = string<br/>      type_handler_version                      = string<br/>      auto_upgrade_minor_version_enabled        = optional(bool, true)<br/>      settings                                  = optional(string)<br/>      protected_settings                        = optional(string)<br/>      extensions_to_provision_after_vm_creation = optional(list(string))<br/>      failure_suppression_enabled               = optional(bool)<br/>      force_extension_execution_on_change       = optional(string)<br/>      protected_settings_from_key_vault = optional(object({<br/>        secret_url      = string<br/>        source_vault_id = string<br/>      }))<br/>    })), {})<br/><br/>    identity = optional(object({<br/>      type         = optional(string, "UserAssigned")<br/>      identity_ids = set(string)<br/>    }))<br/><br/>    boot_diagnostics = optional(object({<br/>      enabled             = optional(bool, true)<br/>      storage_account_uri = optional(string)<br/>    }), {})<br/><br/>    priority        = optional(string, "Regular")<br/>    eviction_policy = optional(string)<br/>    max_bid_price   = optional(number)<br/>    priority_mix = optional(object({<br/>      base_regular_count            = optional(number)<br/>      regular_percentage_above_base = optional(number)<br/>    }))<br/><br/>    upgrade_mode = optional(string)<br/>    rolling_upgrade_policy = optional(object({<br/>      max_batch_instance_percent              = optional(number, 20)<br/>      max_unhealthy_instance_percent          = optional(number, 20)<br/>      max_unhealthy_upgraded_instance_percent = optional(number, 20)<br/>      pause_time_between_batches              = optional(string, "PT30S")<br/>      cross_zone_upgrades_enabled             = optional(bool)<br/>      maximum_surge_instances_enabled         = optional(bool)<br/>      prioritize_unhealthy_instances_enabled  = optional(bool)<br/>    }))<br/><br/>    automatic_instance_repair = optional(object({<br/>      enabled      = bool<br/>      grace_period = optional(string)<br/>      action       = optional(string)<br/>    }))<br/><br/>    termination_notification = optional(object({<br/>      enabled = bool<br/>      timeout = optional(string)<br/>    }))<br/><br/>    user_data                     = optional(string)<br/>    ultra_ssd_enabled             = optional(bool)<br/>    capacity_reservation_group_id = optional(string)<br/>    proximity_placement_group_id  = optional(string)<br/>    license_type                  = optional(string)<br/>    encryption_at_host_enabled    = optional(bool)<br/>    extension_operations_enabled  = optional(bool)<br/>    extensions_time_budget        = optional(string)<br/>    network_api_version           = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the scale sets (merged with per-scale-set tags). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identities"></a> [identities](#output\_identities) | Map of scale set name to its identity block (user-assigned ids), when one is set. |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of scale set name to its resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of scale set name to a { name, id } object, for passing where both are needed together. |
| <a name="output_image_catalog_keys"></a> [image\_catalog\_keys](#output\_image\_catalog\_keys) | The friendly image keys accepted by source\_image\_simple. |
| <a name="output_names"></a> [names](#output\_names) | The scale set names. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group name parsed from resource\_group\_id. |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Subscription id parsed from resource\_group\_id. |
| <a name="output_tags"></a> [tags](#output\_tags) | The base tags applied to the scale sets. |
| <a name="output_unique_ids"></a> [unique\_ids](#output\_unique\_ids) | Map of scale set name to its Azure unique id. |
<!-- END_TF_DOCS -->
