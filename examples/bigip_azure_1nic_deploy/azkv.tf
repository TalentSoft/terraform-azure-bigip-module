data "azurerm_client_config" "current" {
}

resource azurerm_resource_group rgkeyvault {
  name     = format("%s-%s", var.azure_secret_rg, random_id.id.hex)
  location = var.location
}

resource random_id server {
  keepers = {
    ami_id = 1
  }
  byte_length = 8
}

resource "azurerm_user_assigned_identity" "user_identity" {
  name                = format("%s-%s-ident", var.prefix, random_id.id.hex)
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}


resource azurerm_key_vault azkv {
  name                        = format("%s-%s", var.azure_keyvault_name, random_id.id.hex)
  location                    = azurerm_resource_group.rgkeyvault.location
  resource_group_name         = azurerm_resource_group.rgkeyvault.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
    ]
    secret_permissions = ["get", "list", "set", "delete", "recover", "backup", "restore", "purge"]
    storage_permissions = [
      "get",
    ]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.user_identity.principal_id
    key_permissions = [
      "get", "list", "update", "create", "import", "delete", "recover", "backup", "restore",
    ]
    secret_permissions = ["get", "list", "set", "delete", "recover", "backup", "restore", "purge"]
    storage_permissions = [
      "get",
    ]
  }
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = {
    environment = "Testing"
  }
}

#
# Create random password for BIG-IP
#
resource random_string password {
  length      = 16
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  special     = false
}

resource azurerm_key_vault_secret azkvsec {
  name         = format("%s-%s", var.azure_keyvault_secret_name, random_id.id.hex)
  value        = random_string.password.result
  key_vault_id = azurerm_key_vault.azkv.id

  tags = {
    environment = "Testing"
  }
}