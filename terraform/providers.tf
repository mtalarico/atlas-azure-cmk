terraform {
  required_providers {
    mongodbatlas = {
      source = "mongodb/mongodbatlas"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}

provider "mongodbatlas" {
  public_key  = data.vault_kv_secret.atlas_creds.data["public_key"]
  private_key = data.vault_kv_secret.atlas_creds.data["private_key"]
}

data "vault_kv_secret" "atlas_creds" {
  path = var.vault.api_key_path
}

provider "vault" {
  address = var.vault.uri
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}
