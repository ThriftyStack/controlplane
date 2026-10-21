terraform {
  required_version = ">= 1.12.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.1"
    }
  }
}

variable "roles" {
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
}

locals {
  permissions = merge({}, [for role_key, role in var.roles : {
    for permission_key, permission in role.permissions : "${role_key}.${permission_key}" => merge(permission, { role = role_key })
  }]...)
  initial_permissions = merge({}, [for role_key, role in var.roles : {
    for permission_key, permission in role.initial_permissions : "${role_key}.${permission_key}" => merge(permission, { role = role_key })
  }]...)
}

resource "authentik_rbac_role" "this" {
  for_each = var.roles

  name = each.value.name
}

resource "authentik_rbac_permission_role" "this" {
  for_each = local.permissions

  role       = authentik_rbac_role.this[each.value.role].id
  permission = each.value.permission
  model      = each.value.model
  object_id  = each.value.object_id
}

resource "authentik_rbac_initial_permissions" "this" {
  for_each = local.initial_permissions

  name        = each.value.name
  role        = authentik_rbac_role.this[each.value.role].id
  permissions = each.value.permissions
}

output "ids" {
  value = { for key, role in authentik_rbac_role.this : key => role.id }
}

output "roles" {
  value = authentik_rbac_role.this
}

output "permissions" {
  value = authentik_rbac_permission_role.this
}

output "initial_permissions" {
  value = authentik_rbac_initial_permissions.this
}
