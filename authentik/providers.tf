# Kubernetes login reads the projected service account token at runtime.
# OpenTofu evaluates file() during validate, which runs outside the pod, so
# try() keeps that check hermetic. When the token is mounted, file() returns
# it; when it is not, the login JWT is empty and Vault rejects it.
# The Authentik API token stays an ephemeral read so it never lands in state.
provider "vault" {
  address = var.vault_addr

  auth_login {
    path = "auth/kubernetes-management/login"

    parameters = {
      role = "authentik-tofu"
      jwt  = try(file("/var/run/vault-auth/token"), "")
    }
  }
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
