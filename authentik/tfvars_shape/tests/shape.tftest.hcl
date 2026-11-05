# terraform.tfvars is loaded with the real variable types, including
# adoption_ids. An OAuth2 application nested under outposts or proxy_apps
# fails decoding before these asserts.

run "minio_stays_an_oauth2_app" {
  command = plan

  assert {
    condition = alltrue([
      contains(keys(var.oauth2_apps), "minio"),
      !contains(keys(var.outposts), "minio"),
      !contains(keys(var.proxy_apps), "minio"),
      var.oauth2_apps["minio"].name == "MinIO",
      var.oauth2_apps["minio"].group == "Infrastructure",
      toset(var.oauth2_apps["minio"].scopes) == toset(["openid", "profile", "email", "groups"]),
      length(var.oauth2_apps["minio"].redirects) == 1,
      var.oauth2_apps["minio"].redirects[0].matching_mode == "strict",
      var.oauth2_apps["minio"].redirects[0].url == "https://minio-ui.adminio.biz:9001/oauth_callback",
      var.oauth2_apps["minio"].redirects[0].redirect_uri_type == "authorization",
      var.oauth2_apps["minio"].entitlements["minio_admins"] == "consoleAdmin",
      var.oauth2_apps["minio"].client_id == { path = "authentik/clients", key = "minio-client-id" },
      var.oauth2_apps["minio"].client_secret == { path = "authentik/clients", key = "minio" },
      var.bindings["minio"].target_type == "oauth2_app",
      var.bindings["minio"].target == "minio",
      var.bindings["minio_admins"].target_type == "entitlement",
      var.bindings["minio_admins"].target == "minio_admins",
      toset(keys(var.outposts)) == toset(["oke"]),
      var.adoption_ids.proxmox_admins_entitlement == "857de816-5a3f-4983-a0a2-e1007957112f",
      var.adoption_ids.grafana_provider == "6",
      var.adoption_ids.proxmox_provider == "5",
      var.adoption_ids.vault_provider == "4",
      var.adoption_ids.longhorn_provider == "3",
      can(regex("^[0-9]+$", var.adoption_ids.grafana_provider)),
      can(regex("^[0-9]+$", var.adoption_ids.proxmox_provider)),
      can(regex("^[0-9]+$", var.adoption_ids.vault_provider)),
      can(regex("^[0-9]+$", var.adoption_ids.longhorn_provider)),
      var.adoption_ids.oke_outpost == "729e49a1-6b9f-4776-a2bf-71c4a824d69e",
      var.adoption_ids.entitlement_groups_scope == "a5ebb0c0-0c96-4105-9e50-f6d08fb0e25c",
    ])
    error_message = "minio must stay an oauth2_apps entry with entitlement minio_admins = consoleAdmin, and adoption_ids must be the live pbm uuid, numeric proxy pk, outpost uuid, and groups scope-mapping pk from terraform.tfvars."
  }
}
