# Plan-time tests for the module. The provider is mocked, so no credentials, no features block,
# and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  location          = "uksouth"
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01"

  scale_sets = {
    "vmssldoukststs01" = {
      sku_name  = "Standard_D2lds_v6"
      instances = 1

      source_image_simple = "Ubuntu2404"
      user_data           = "echo hello"

      os_profile = {
        linux = {
          admin_username = "azureuser"
          admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
        }
      }

      network_interfaces = {
        "nic" = {
          ip_configurations = {
            "internal" = { subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/virtualNetworks/vnet-ldo-uks-tst-01/subnets/snet-app-vnet-ldo-uks-tst-01" }
          }
        }
      }
    }
  }
}

# Defaults: zone-redundant, fault domain count 1, SSH-only, catalog resolution, primary NIC and
# ipconfig auto-marked, user_data base64-encoded, managed boot diagnostics.
run "secure_defaults" {
  command = plan

  assert {
    condition     = tolist(azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].zones) == tolist(["1", "2", "3"])
    error_message = "Scale sets should be zone-redundant by default."
  }

  assert {
    condition     = azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].platform_fault_domain_count == 1
    error_message = "platform_fault_domain_count should default to 1 (max spreading)."
  }

  assert {
    condition     = azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].os_profile[0].linux_configuration[0].disable_password_authentication == true
    error_message = "Linux should be SSH-only by default."
  }

  assert {
    condition     = azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].source_image_reference[0].publisher == "Canonical"
    error_message = "source_image_simple should resolve through the catalog."
  }

  assert {
    condition     = azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].network_interface[0].primary == true
    error_message = "A single NIC should be primary automatically."
  }

  assert {
    condition     = azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].user_data_base64 == base64encode("echo hello")
    error_message = "user_data should be base64-encoded by the module."
  }

  assert {
    condition     = length(azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].boot_diagnostics) == 1
    error_message = "Managed boot diagnostics should be on by default."
  }
}

# A mixed-size profile forces sku_name to Mix.
run "sku_profile_forces_mix" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_profile = {
          virtual_machine_sizes = [{ name = "Standard_D2lds_v6" }, { name = "Standard_D2als_v6", rank = 1 }]
        }
        instances           = 1
        source_image_simple = "Ubuntu2404"
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/virtualNetworks/vnet-ldo-uks-tst-01/subnets/snet-app-vnet-ldo-uks-tst-01" }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].sku_name == "Mix"
    error_message = "A sku_profile should force sku_name to Mix."
  }
}

# The Rocky catalog entry carries a marketplace plan; accepting flows an agreement resource.
run "catalog_plan_flows_through" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name                     = "Standard_D2lds_v6"
        instances                    = 1
        source_image_simple          = "Rocky9"
        accept_marketplace_agreement = true
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Network/virtualNetworks/vnet-ldo-uks-tst-01/subnets/snet-app-vnet-ldo-uks-tst-01" }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = azurerm_orchestrated_virtual_machine_scale_set.this["vmssldoukststs01"].plan[0].publisher == "resf"
    error_message = "The catalog-carried plan should flow into the plan block."
  }

  assert {
    condition     = length(azurerm_marketplace_agreement.this) == 1
    error_message = "accept_marketplace_agreement should create one deduplicated agreement."
  }
}

# The resource group is parsed from the id and exposed as an output.
run "parses_resource_group" {
  command = plan

  assert {
    condition     = output.resource_group_name == "rg-ldo-uks-tst-01"
    error_message = "resource_group_name should be parsed from resource_group_id."
  }
}

# Validation: an unknown catalog key fails the plan with the key list.
run "rejects_unknown_catalog_key" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name            = "Standard_D2lds_v6"
        source_image_simple = "NotAnImage"
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/s/x" }
            }
          }
        }
      }
    }
  }

  expect_failures = [azurerm_orchestrated_virtual_machine_scale_set.this]
}

# Validation: both OS configurations at once are rejected.
run "rejects_both_os_configurations" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name            = "Standard_D2lds_v6"
        source_image_simple = "Ubuntu2404"
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
          windows = {
            admin_username = "azureadmin"
            admin_password = "Sup3rS3cret!!"
          }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/s/x" }
            }
          }
        }
      }
    }
  }

  expect_failures = [var.scale_sets]
}

# Validation: a Linux set without SSH keys (and SSH-only default) is rejected.
run "rejects_linux_without_ssh_keys" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name            = "Standard_D2lds_v6"
        source_image_simple = "Ubuntu2404"
        os_profile = {
          linux = { admin_username = "azureuser" }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/s/x" }
            }
          }
        }
      }
    }
  }

  expect_failures = [var.scale_sets]
}

# Validation: sku_name and sku_profile are mutually exclusive.
run "rejects_sku_name_and_profile" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name = "Standard_D2lds_v6"
        sku_profile = {
          virtual_machine_sizes = [{ name = "Standard_D2lds_v6" }]
        }
        source_image_simple = "Ubuntu2404"
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/s/x" }
            }
          }
        }
      }
    }
  }

  expect_failures = [var.scale_sets]
}

# Validation: spot-only fields demand priority = Spot.
run "rejects_spot_fields_on_regular" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name            = "Standard_D2lds_v6"
        source_image_simple = "Ubuntu2404"
        eviction_policy     = "Delete"
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/s/x" }
            }
          }
        }
      }
    }
  }

  expect_failures = [var.scale_sets]
}

# Validation: a rolling upgrade policy without Rolling mode is rejected.
run "rejects_rolling_policy_without_rolling_mode" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name               = "Standard_D2lds_v6"
        source_image_simple    = "Ubuntu2404"
        rolling_upgrade_policy = {}
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
        }
        network_interfaces = {
          "nic" = {
            ip_configurations = {
              "internal" = { subnet_id = "/s/x" }
            }
          }
        }
      }
    }
  }

  expect_failures = [var.scale_sets]
}

# Validation: two NICs without an explicit primary are rejected.
run "rejects_ambiguous_primary_nic" {
  command = plan

  variables {
    scale_sets = {
      "vmssldoukststs01" = {
        sku_name            = "Standard_D2lds_v6"
        source_image_simple = "Ubuntu2404"
        os_profile = {
          linux = {
            admin_username = "azureuser"
            admin_ssh_keys = [{ public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtbmPhzCR+ZpI/Y4H1IvPEI+tvGT4R5ReLtj5QZVcRXJiRdIbYsb6sjaYu8JcR6vzSHAlJcx0zmcSP4SR7HqtuXbODv+OvVpBCoil9LWbCfOgOQ6XZ3oSFYe8lFllbFLiM7I+ok+s7Cygnu58fil7pDdBFrS7DZRjvT87RrOX0dp2LDNNN7LYFy5nwHvkBv9z36q9RFGcP4e0XDNtU0+LGnolz4oDWkJt/0POaHIxnJJX7ge0r0bReZq/t1XRr/RrhPYk6gkWsSkfbwwxGPA2UdxFRDVn2aMx6Hz8gQfcHRS2kEvKRMIgQfBOmB6OInLCLaUZRWm5YdEBZXwtdREor example" }]
          }
        }
        network_interfaces = {
          "nic1" = {
            ip_configurations = { "a" = { subnet_id = "/s/x" } }
          }
          "nic2" = {
            ip_configurations = { "b" = { subnet_id = "/s/x" } }
          }
        }
      }
    }
  }

  expect_failures = [var.scale_sets]
}
