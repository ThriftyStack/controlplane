terraform {
  # OpenTofu 1.11 mock providers panic on ephemeral resources.
  required_version = ">= 1.12.0"

  required_providers {
    # This release targets Authentik 2026.5 and includes its generated API client.
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }

  # The Workspace GCP key supplies GOOGLE_APPLICATION_CREDENTIALS for this backend.
  backend "gcs" {
    bucket = "project-d10f7f85-317f-426a-a46-tofu-state"
    prefix = "controlplane/authentik"
  }
}
