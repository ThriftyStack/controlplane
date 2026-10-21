terraform {
  required_version = ">= 1.12.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.1"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

variable "apps" {
  type = map(object({
    name   = string
    group  = string
    scopes = set(string)
    redirects = list(object({
      matching_mode     = string
      url               = string
      redirect_uri_type = string
    }))
    client_id = object({
      path = string
      key  = string
    })
    client_secret = object({
      path = string
      key  = string
    })
    logout_method = optional(string, "backchannel")
    logout_uri    = optional(string)
    entitlements  = optional(map(string), {})
  }))
}

variable "vault_mount" {
  type = string
}

locals {
  client_ids = {
    for slug, app in var.apps : slug => try(data.vault_kv_secret_v2.credentials[app.client_id.path].data[app.client_id.key], "")
  }
  nonempty_client_ids = [for id in values(local.client_ids) : trimspace(id) if trimspace(id) != ""]
  client_secrets = {
    for slug, app in var.apps : slug => try(data.vault_kv_secret_v2.credentials[app.client_secret.path].data[app.client_secret.key], "")
  }
  entitlements = merge({}, [for slug, app in var.apps : {
    for key, name in app.entitlements : key => { application = slug, name = name }
  }]...)
  scopes = toset(flatten([for app in values(var.apps) : tolist(app.scopes)]))
}

# Client-secret resource arguments are not write-only in this provider.
data "vault_kv_secret_v2" "credentials" {
  for_each = toset(flatten([
    for app in values(var.apps) : [app.client_id.path, app.client_secret.path]
  ]))

  mount = var.vault_mount
  name  = each.value
}

data "authentik_flow" "authorization" {
  count = length(var.apps) > 0 ? 1 : 0
  slug  = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "invalidation" {
  count = length(var.apps) > 0 ? 1 : 0
  slug  = "default-provider-invalidation-flow"
}

data "authentik_certificate_key_pair" "signing" {
  count             = length(var.apps) > 0 ? 1 : 0
  name              = "authentik Self-signed Certificate"
  fetch_key         = false
  fetch_certificate = false
}

data "authentik_property_mapping_provider_scope" "default" {
  for_each = setsubtract(local.scopes, toset(["groups"]))
  managed  = "goauthentik.io/providers/oauth2/scope-${each.key}"
}

resource "authentik_property_mapping_provider_scope" "entitlement_groups" {
  count       = contains(local.scopes, "groups") ? 1 : 0
  name        = "Homelab application entitlement groups"
  scope_name  = "groups"
  description = "Application-scoped entitlement names"
  expression  = <<-PY
    return {
        "groups": sorted(
            entitlement.name
            for entitlement in request.user.app_entitlements(provider.application)
        ),
    }
  PY
}

resource "authentik_provider_oauth2" "this" {
  for_each = var.apps

  name                  = each.value.name
  client_id             = local.client_ids[each.key]
  client_secret         = local.client_secrets[each.key]
  client_type           = "confidential"
  authorization_flow    = data.authentik_flow.authorization[0].id
  invalidation_flow     = data.authentik_flow.invalidation[0].id
  grant_types           = ["authorization_code"]
  issuer_mode           = "per_provider"
  allowed_redirect_uris = each.value.redirects
  signing_key           = data.authentik_certificate_key_pair.signing[0].id
  logout_method         = each.value.logout_method
  logout_uri            = each.value.logout_uri
  property_mappings = [for scope in each.value.scopes :
    scope == "groups" ? authentik_property_mapping_provider_scope.entitlement_groups[0].id : data.authentik_property_mapping_provider_scope.default[scope].id
  ]

  lifecycle {
    precondition {
      condition     = trimspace(local.client_ids[each.key]) != ""
      error_message = "Vault ${var.vault_mount}/${each.value.client_id.path} has no non-empty key ${each.value.client_id.key} for the ${each.key} OAuth2 client ID."
    }

    precondition {
      condition     = trimspace(local.client_secrets[each.key]) != ""
      error_message = "Vault ${var.vault_mount}/${each.value.client_secret.path} has no non-empty key ${each.value.client_secret.key} for the ${each.key} OAuth2 client secret."
    }

    precondition {
      condition     = length(distinct(local.nonempty_client_ids)) == length(local.nonempty_client_ids)
      error_message = "OAuth2 client IDs resolved from Vault must be unique."
    }
  }
}

resource "authentik_application" "this" {
  for_each = var.apps

  name              = each.value.name
  slug              = each.key
  group             = each.value.group
  protocol_provider = authentik_provider_oauth2.this[each.key].id
}

resource "authentik_application_entitlement" "this" {
  for_each = local.entitlements

  application = authentik_application.this[each.value.application].uuid
  name        = each.value.name
}

output "application_ids" {
  value = { for key, app in authentik_application.this : key => app.uuid }
}

output "entitlement_ids" {
  value = { for key, entitlement in authentik_application_entitlement.this : key => entitlement.id }
}

output "applications" {
  value = authentik_application.this
}

output "entitlements" {
  value = authentik_application_entitlement.this
}

output "providers" {
  sensitive = true
  value = { for key, provider in authentik_provider_oauth2.this : key => {
    id                    = provider.id
    name                  = provider.name
    client_id             = provider.client_id
    client_type           = provider.client_type
    grant_types           = provider.grant_types
    issuer_mode           = provider.issuer_mode
    authorization_flow    = provider.authorization_flow
    invalidation_flow     = provider.invalidation_flow
    signing_key           = provider.signing_key
    allowed_redirect_uris = provider.allowed_redirect_uris
    logout_method         = provider.logout_method
    logout_uri            = provider.logout_uri
    property_mappings     = provider.property_mappings
  } }
}

output "credential_paths" {
  value = { for path, secret in data.vault_kv_secret_v2.credentials : path => secret.name }
}

output "default_scopes" {
  value = data.authentik_property_mapping_provider_scope.default
}

output "entitlement_groups_scope" {
  value = authentik_property_mapping_provider_scope.entitlement_groups
}
