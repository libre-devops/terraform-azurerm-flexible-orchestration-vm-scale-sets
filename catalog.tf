# The image catalog: friendly keys for the marketplace images people actually mean, one structured
# in-module map covering both OS flavours (a flexible scale set is Linux or Windows per entry).
# Copied verbatim from the linux-vm and windows-vm modules, where every reference was verified
# against the live marketplace (az vm image show, 2026-07-02/03): all are Gen2 images. Only Rocky
# carries a marketplace plan (it flows through, set accept_marketplace_agreement = true on first
# use).
#
# Discover the keys with the image_catalog_keys output; pick one with source_image_simple.
# source_image_reference and source_image_id remain first-class for anything the catalog does not
# carry.
locals {
  image_catalog = {
    Ubuntu2204 = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      plan      = null
    }
    Ubuntu2404 = {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      plan      = null
    }
    Debian12 = {
      publisher = "Debian"
      offer     = "debian-12"
      sku       = "12-gen2"
      plan      = null
    }
    RHEL9 = {
      publisher = "RedHat"
      offer     = "RHEL"
      sku       = "9-lvm-gen2"
      plan      = null
    }
    Sles15 = {
      publisher = "SUSE"
      offer     = "sles-15-sp6"
      sku       = "gen2"
      plan      = null
    }
    Rocky9 = {
      publisher = "resf"
      offer     = "rockylinux-x86_64"
      sku       = "9-base"
      plan = {
        name      = "9-base"
        product   = "rockylinux-x86_64"
        publisher = "resf"
      }
    }
    WindowsServer2022 = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-g2"
      plan      = null
    }
    WindowsServer2022AzureEdition = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      plan      = null
    }
    WindowsServer2025 = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2025-datacenter-g2"
      plan      = null
    }
    WindowsServer2025AzureEdition = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2025-datacenter-azure-edition"
      plan      = null
    }
  }

  # Catalog keys whose images support hotpatching, per the provider's sku allow-list.
  hotpatch_capable_keys = ["WindowsServer2025AzureEdition"]
}
