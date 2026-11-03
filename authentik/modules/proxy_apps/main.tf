terraform {
  required_version = ">= 1.12.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.1"
    }
  }
}

variable "apps" {
  type = map(object({
    name          = string
    group         = string
    external_host = string
    internal_host = string
    entitlements  = optional(map(string), {})
  }))
}

variable "outposts" {
  type = map(object({
    name           = string
    authentik_host = string
    providers      = list(string)
  }))
}

locals {
  entitlements = merge({}, [for slug, app in var.apps : {
    for key, name in app.entitlements : key => { application = slug, name = name }
  }]...)
}

data "authentik_flow" "authorization" {
  count = length(var.apps) > 0 ? 1 : 0
  slug  = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "invalidation" {
  count = length(var.apps) > 0 ? 1 : 0
  slug  = "default-provider-invalidation-flow"
}

resource "authentik_provider_proxy" "this" {
  for_each = var.apps

  name               = each.value.name
  external_host      = each.value.external_host
  internal_host      = each.value.internal_host
  authorization_flow = data.authentik_flow.authorization[0].id
  invalidation_flow  = data.authentik_flow.invalidation[0].id

  # mode defaults to proxy and would retarget the outpost if the live value
  # differs. The other ignored arguments have the same problem.
  lifecycle {
    ignore_changes = [
      mode,
      access_token_validity,
      refresh_token_validity,
      intercept_header_auth,
      basic_auth_enabled,
      basic_auth_username_attribute,
      basic_auth_password_attribute,
      internal_host_ssl_validation,
      cookie_domain,
      property_mappings,
      authentication_flow,
      skip_path_regex,
      jwt_federation_sources,
      jwt_federation_providers,
      jwks_sources,
    ]
  }
}

resource "authentik_application" "this" {
  for_each = var.apps

  name              = each.value.name
  slug              = each.key
  group             = each.value.group
  protocol_provider = authentik_provider_proxy.this[each.key].id

  lifecycle {
    ignore_changes = [
      meta_description,
      meta_icon,
      meta_launch_url,
      meta_publisher,
    ]
  }
}

resource "authentik_application_entitlement" "this" {
  for_each = local.entitlements

  application = authentik_application.this[each.value.application].uuid
  name        = each.value.name
}

resource "authentik_outpost" "this" {
  for_each = var.outposts

  name = each.value.name
  protocol_providers = [
    for key in each.value.providers : tonumber(authentik_provider_proxy.this[key].id)
  ]
  # The API stores this object as given and returns it unchanged. The verified
  # legacy tfvars set authentik_host and no other config key.
  config = jsonencode({
    authentik_host = each.value.authentik_host
  })

  # service_connection is the live OKE kube connection. Clearing it deletes
  # the outpost Deployment.
  lifecycle {
    ignore_changes = [service_connection]
  }
}

output "application_ids" {
  value = { for key, app in authentik_application.this : key => app.uuid }
}

output "entitlement_ids" {
  value = { for key, entitlement in authentik_application_entitlement.this : key => entitlement.id }
}
