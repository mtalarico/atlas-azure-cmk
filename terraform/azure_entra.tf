data "azuread_client_config" "current" {}

resource "azuread_application_registration" "example_cmk_app_reg" {
  display_name     = "${var.azure.prefix}-atlas-cmk"
  description      = "Atlas CMK EAR"
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "example_cmk_sp" {
  client_id                    = azuread_application_registration.example_cmk_app_reg.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "example_cmk_pass" {
  application_id = azuread_application_registration.example_cmk_app_reg.id
}
