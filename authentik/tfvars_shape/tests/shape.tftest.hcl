# terraform.tfvars is loaded with the real variable types. An OAuth2 application
# nested under outposts or proxy_apps fails decoding before these asserts.

variables {
  adoption_ids = {
    proxmox_admins_entitlement = "test-only-not-a-live-id"
    longhorn_provider          = "test-only-not-a-live-id"
    oke_outpost                = "test-only-not-a-live-id"
  }
}

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
    ])
    error_message = "minio must be an oauth2_apps entry with entitlement minio_admins = consoleAdmin. Nesting it under outposts drops the application and its bindings."
  }
}
