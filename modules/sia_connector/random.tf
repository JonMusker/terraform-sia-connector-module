# -------------------------------------------------------------------
# Random password for the VM
# -------------------------------------------------------------------

resource "random_password" "vm_admin_password"{
  length           = 24
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  lower            = true
  upper            = true
  numeric          = true
  special          = true
  override_special = "$-.!;:#'@"
}
