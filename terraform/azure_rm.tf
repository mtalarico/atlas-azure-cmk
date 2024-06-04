data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example_cmk_rg" {
  name     = "${var.azure.prefix}-example-cmk-rg"
  location = "East US"
}

resource "azurerm_key_vault" "example_cmk_kv" {
  name                        = "${var.azure.prefix}-example-cmk-rg"
  location                    = azurerm_resource_group.example_cmk_rg.location
  resource_group_name         = azurerm_resource_group.example_cmk_rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"
}

resource "azurerm_key_vault_access_policy" "example_cmk_kv_ap" {
  key_vault_id = azurerm_key_vault.example_cmk_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.example_cmk_sp.object_id

  key_permissions = [
    "Get", "List", "Encrypt", "Decrypt"
  ]
}

# I had to do this in order execute the terraform script,
# this is MY personal Azure account's OID getting full permissions on the vault
resource "azurerm_key_vault_access_policy" "tf_client" {
  key_vault_id = azurerm_key_vault.example_cmk_kv.id
  tenant_id    = data.azuread_client_config.current.tenant_id
  object_id    = data.azuread_client_config.current.object_id

  key_permissions = [
    "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey", "Release", "Rotate", "GetRotationPolicy", "SetRotationPolicy"
  ]
}

resource "azurerm_key_vault_key" "example_cmk_kv_key" {
  name         = "generated-certificate"
  key_vault_id = azurerm_key_vault.example_cmk_kv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }

  depends_on = [azurerm_key_vault_access_policy.example_cmk_kv_ap, azurerm_key_vault_access_policy.tf_client]
}

resource "azurerm_role_assignment" "example" {
  # azurerm_key_vault_key.generated.resource_versionless_id *does not work* for scope
  scope                = azurerm_key_vault.example_cmk_kv.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azuread_service_principal.example_cmk_sp.object_id
}
