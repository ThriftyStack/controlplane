variable "vault_addr" {
  description = "Vault address the provider logs in to. The Workspace overrides this with the in-cluster management Vault."
  type        = string
  default     = "https://vault.devoops.uk"
}

variable "vault_secret_mount" {
  description = "Vault KV v2 mount holding Authentik credentials."
  type        = string
  default     = "infra"
}

variable "authentik_secret_name" {
  description = "Vault KV v2 path below vault_secret_mount holding the Authentik API token."
  type        = string
  default     = "authentik"
}

variable "authentik_token_field" {
  description = "Key in the Vault secret containing the Authentik API token."
  type        = string
  default     = "tofu-api-token"
}

variable "authentik_url" {
  description = "Base URL of the Authentik API."
  type        = string
  default     = "https://auth.devoops.uk"

  validation {
    condition     = can(regex("^https://[^/]+/?$", var.authentik_url))
    error_message = "authentik_url must be https://<host> with no path component."
  }
}

variable "roles" {
  description = "Directory RBAC roles keyed by stable configuration name."
  type = map(object({
    name = string
    permissions = optional(map(object({
      permission = string
      model      = optional(string)
      object_id  = optional(string)
    })), {})
    initial_permissions = optional(map(object({
      name        = string
      permissions = set(number)
    })), {})
  }))

  validation {
    condition = alltrue(flatten([for key, role in var.roles : concat(
      [trimspace(key) != "", trimspace(role.name) != ""],
      [for permission in values(role.permissions) : trimspace(permission.permission) != ""],
      [for initial in values(role.initial_permissions) : trimspace(initial.name) != "" && length(initial.permissions) > 0],
    )]))
    error_message = "Roles, permissions, and initial-permission entries require non-empty keys and names; initial-permission sets cannot be empty."
  }
}

variable "groups" {
  description = "Directory groups keyed by stable name; parent relationships determine creation order."
  type = map(object({
    name         = string
    parents      = optional(set(string), [])
    roles        = optional(set(string), [])
    is_superuser = optional(bool, false)
  }))

  validation {
    condition = alltrue([for key, group in var.groups : alltrue([
      trimspace(key) != "",
      trimspace(group.name) != "",
      alltrue([for parent in group.parents : contains(keys(var.groups), parent)]),
      alltrue([for role in group.roles : contains(keys(var.roles), role)]),
    ])])
    error_message = "Groups need non-empty keys and names plus existing parent and role keys."
  }
}

variable "oauth2_apps" {
  description = "OAuth2 applications keyed by Authentik application slug."
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

  validation {
    condition = alltrue([for slug, app in var.oauth2_apps : alltrue([
      trimspace(slug) != "",
      trimspace(app.name) != "",
      trimspace(app.group) != "",
      contains(app.scopes, "openid"),
      anytrue([for redirect in app.redirects : redirect.redirect_uri_type == "authorization"]),
      trimspace(app.client_id.path) != "",
      trimspace(app.client_id.key) != "",
      trimspace(app.client_secret.path) != "",
      trimspace(app.client_secret.key) != "",
      alltrue([for key, name in app.entitlements : trimspace(key) != "" && trimspace(name) != ""]),
    ])])
    error_message = "Each OAuth2 application needs non-empty settings, openid scope, an authorization redirect, valid Vault references, and valid entitlements."
  }

  validation {
    condition = length(flatten([for app in values(var.oauth2_apps) : keys(app.entitlements)])) == length(distinct(flatten([
      for app in values(var.oauth2_apps) : keys(app.entitlements)
    ])))
    error_message = "Entitlement keys must be unique across all OAuth2 applications."
  }
}

variable "policies" {
  description = "Expression policies keyed by stable configuration name."
  type = map(object({
    name              = string
    expression        = string
    execution_logging = optional(bool, false)
  }))

  validation {
    condition = alltrue([for key, policy in var.policies : alltrue([
      trimspace(key) != "",
      trimspace(policy.name) != "",
      trimspace(policy.expression) != "",
    ])])
    error_message = "Policies require non-empty keys, names, and expressions."
  }
}

variable "bindings" {
  description = "Group or expression-policy access bindings for applications and entitlements."
  type = map(object({
    target_type    = string
    target         = string
    subject_type   = string
    subject        = string
    order          = optional(number, 0)
    enabled        = optional(bool, true)
    negate         = optional(bool, false)
    failure_result = optional(bool, false)
    timeout        = optional(number, 30)
  }))

  validation {
    condition = alltrue([for key, binding in var.bindings : alltrue([
      trimspace(key) != "",
      contains(["oauth2_app", "entitlement"], binding.target_type),
      contains(["group", "policy"], binding.subject_type),
      binding.target_type == "oauth2_app" ? contains(keys(var.oauth2_apps), binding.target) : contains(distinct(flatten([for app in values(var.oauth2_apps) : keys(app.entitlements)])), binding.target),
      binding.subject_type == "group" ? contains(keys(var.groups), binding.subject) : contains(keys(var.policies), binding.subject),
    ])])
    error_message = "Bindings require existing application or entitlement targets and existing group or policy subjects."
  }
}
