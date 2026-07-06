# Post-plan sanity checks: informational (warn), they never fail an apply.

check "has_scale_sets" {
  assert {
    condition     = length(var.scale_sets) > 0
    error_message = "No scale sets are defined: the module call creates nothing."
  }
}

# Password auth on Linux is an explicit opt-out of the SSH-only default; make it visible.
check "linux_password_auth_optins_are_visible" {
  assert {
    # try() guards the null side: 1.9 evaluates both || operands.
    condition = alltrue([
      for s in values(var.scale_sets) :
      try(s.os_profile.linux.disable_password_authentication, true)
    ])
    error_message = "At least one Linux scale set enables password authentication: prefer SSH keys (the default)."
  }
}

# Automatic instance repair without an application health extension never repairs anything; Azure
# also rejects enabling it without one at apply time on some paths. Surface the pairing early.
check "instance_repair_has_health_extension" {
  assert {
    # try() guards the null side: 1.9 evaluates both || operands.
    condition = alltrue([
      for s in values(var.scale_sets) :
      !try(s.automatic_instance_repair.enabled, false) || anytrue([
        for e in values(s.extensions) : contains(["ApplicationHealthLinux", "ApplicationHealthWindows"], e.type)
      ])
    ])
    error_message = "At least one scale set enables automatic_instance_repair without an Application Health extension (type ApplicationHealthLinux or ApplicationHealthWindows)."
  }
}
