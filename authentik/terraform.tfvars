roles = {}

groups = {
  homelab_users = {
    name = "homelab-users"
  }
  homelab_admins = {
    name    = "homelab-admins"
    parents = ["homelab_users"]
  }
}

oauth2_apps = {
  grafana = {
    name   = "Grafana"
    group  = "Observability"
    scopes = ["openid", "profile", "email", "entitlements"]
    redirects = [
      { matching_mode = "strict", url = "https://grafana.adminio.biz/login/generic_oauth", redirect_uri_type = "authorization" },
      { matching_mode = "strict", url = "https://grafana.adminio.biz/logout", redirect_uri_type = "logout" },
    ]
    client_id     = { path = "authentik/clients", key = "grafana-client-id" }
    client_secret = { path = "authentik/clients", key = "grafana" }
    logout_method = "frontchannel"
    logout_uri    = "https://grafana.adminio.biz/logout"
    entitlements = {
      grafana_admins  = "Grafana Admins"
      grafana_editors = "Grafana Editors"
      grafana_viewers = "Grafana Viewers"
    }
  }
  vault = {
    name   = "Vault"
    group  = "Infrastructure"
    scopes = ["openid", "email", "groups"]
    redirects = [
      { matching_mode = "strict", url = "https://vault.devoops.uk/ui/vault/auth/authentik/oidc/callback", redirect_uri_type = "authorization" },
      { matching_mode = "strict", url = "http://localhost:8250/oidc/callback", redirect_uri_type = "authorization" },
    ]
    client_id     = { path = "authentik/clients", key = "vault-client-id" }
    client_secret = { path = "authentik/clients", key = "vault" }
    entitlements = {
      vault_admins = "Vault Admins"
    }
  }
  proxmox = {
    name   = "Proxmox"
    group  = "Infrastructure"
    scopes = ["openid", "profile", "email", "groups"]
    redirects = [
      { matching_mode = "strict", url = "https://pve.adminio.biz:8006", redirect_uri_type = "authorization" },
    ]
    client_id     = { path = "proxmox-oidc", key = "authentik-client-id" }
    client_secret = { path = "proxmox-oidc", key = "authentik" }
    # PVE maps this groups-claim value to group proxmox-admins-authentik.
    entitlements = {
      proxmox_admins = "proxmox-admins"
    }
  }
  # MinIO reads the groups claim as policy names, so entitlement names must be
  # exact MinIO policy names. A user with no entitlement is refused at login.
  minio = {
    name   = "MinIO"
    group  = "Infrastructure"
    scopes = ["openid", "profile", "email", "groups"]
    redirects = [
      { matching_mode = "strict", url = "https://minio-ui.adminio.biz:9001/oauth_callback", redirect_uri_type = "authorization" },
    ]
    client_id     = { path = "authentik/clients", key = "minio-client-id" }
    client_secret = { path = "authentik/clients", key = "minio" }
    entitlements = {
      minio_admins = "consoleAdmin"
    }
  }
}

# Hosts match the legacy authentik tfvars. Longhorn has no entitlements.
proxy_apps = {
  longhorn = {
    name          = "Longhorn"
    group         = "Infrastructure"
    external_host = "https://longhorn.oci.devoops.uk"
    internal_host = "http://longhorn-frontend.longhorn-system.svc.cluster.local"
  }
}

outposts = {
  oke = {
    name           = "oke"
    authentik_host = "https://auth.devoops.uk"
    providers      = ["longhorn"]
  }
}

policies = {}

bindings = {
  grafana         = { target_type = "oauth2_app", target = "grafana", subject_type = "group", subject = "homelab_users" }
  vault           = { target_type = "oauth2_app", target = "vault", subject_type = "group", subject = "homelab_admins" }
  proxmox         = { target_type = "oauth2_app", target = "proxmox", subject_type = "group", subject = "homelab_admins" }
  proxmox_admins  = { target_type = "entitlement", target = "proxmox_admins", subject_type = "group", subject = "homelab_admins" }
  longhorn        = { target_type = "proxy_app", target = "longhorn", subject_type = "group", subject = "homelab_admins" }
  grafana_admins  = { target_type = "entitlement", target = "grafana_admins", subject_type = "group", subject = "homelab_admins" }
  grafana_viewers = { target_type = "entitlement", target = "grafana_viewers", subject_type = "group", subject = "homelab_users" }
  vault_admins    = { target_type = "entitlement", target = "vault_admins", subject_type = "group", subject = "homelab_admins" }
  minio           = { target_type = "oauth2_app", target = "minio", subject_type = "group", subject = "homelab_admins" }
  minio_admins    = { target_type = "entitlement", target = "minio_admins", subject_type = "group", subject = "homelab_admins" }
}

# Live IDs of existing Authentik objects this root adopts.
adoption_ids = {
  proxmox_admins_entitlement = "857de816-5a3f-4983-a0a2-e1007957112f"
  longhorn_provider          = "3"
  oke_outpost                = "729e49a1-6b9f-4776-a2bf-71c4a824d69e"
}
