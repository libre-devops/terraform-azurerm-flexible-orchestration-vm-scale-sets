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
