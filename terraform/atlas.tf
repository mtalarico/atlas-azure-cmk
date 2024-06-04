data "mongodbatlas_roles_org_id" "example_org" {
}

resource "mongodbatlas_project" "example_cmk_project" {
  name   = "${var.azure.prefix}-example-cmk-project"
  org_id = data.mongodbatlas_roles_org_id.example_org.org_id
}

# resource "mongodbatlas_advanced_cluster" "this" {
#   project_id                  = "618af0d4cf620a3a68d4ea36"
#   name                        = "akv-test-cluster"
#   cluster_type                = "REPLICASET"
#   encryption_at_rest_provider = "AZURE"
#   replication_specs {
#     region_configs {
#       electable_specs {
#         instance_size = "M10"
#         node_count    = 3
#       }

#       provider_name = "AZURE"
#       priority      = 7
#       region_name   = "US_EAST"
#     }
#   }
#   mongo_db_major_version = "7.0"
#   depends_on             = [mongodbatlas_encryption_at_rest.example_cmk_ear]
# }

resource "mongodbatlas_encryption_at_rest" "example_cmk_ear" {
  project_id = mongodbatlas_project.example_cmk_project.id

  azure_key_vault_config {
    enabled             = true
    client_id           = azuread_application_registration.example_cmk_app_reg.client_id
    azure_environment   = "AZURE"
    subscription_id     = data.azurerm_client_config.current.subscription_id
    resource_group_name = azurerm_resource_group.example_cmk_rg.name
    key_vault_name      = azurerm_key_vault.example_cmk_kv.name
    key_identifier      = azurerm_key_vault_key.example_cmk_kv_key.id
    secret              = azuread_application_password.example_cmk_pass.value
    tenant_id           = data.azurerm_client_config.current.tenant_id
  }
}
