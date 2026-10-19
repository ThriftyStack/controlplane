# Ephemeral reads and the provider sink keep both tokens out of state and plans.
provider "google" {
  project = var.project_id
}

ephemeral "google_secret_manager_secret_version" "vault_token" {
  secret = var.vault_token_secret
}

provider "vault" {
  address = var.vault_addr
  token   = ephemeral.google_secret_manager_secret_version.vault_token.secret_data
}

ephemeral "vault_kv_secret_v2" "authentik" {
  mount = var.vault_secret_mount
  name  = var.authentik_secret_name

  lifecycle {
    postcondition {
      condition     = try(trimspace(self.data[var.authentik_token_field]) != "", false)
      error_message = "Vault secret ${var.vault_secret_mount}/${var.authentik_secret_name} must contain a non-empty ${var.authentik_token_field} key."
    }
  }
}

provider "authentik" {
  url   = var.authentik_url
  token = lookup(ephemeral.vault_kv_secret_v2.authentik.data, var.authentik_token_field, "")
}
