terraform {
  required_version = ">= 1.12.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.1"
    }
  }
}

variable "groups" {
  type = map(object({
    name         = string
    parents      = optional(set(string), [])
    roles        = optional(set(string), [])
    is_superuser = optional(bool, false)
  }))
}

variable "role_ids" {
  type = map(string)
}

locals {
  level_0   = { for key, group in var.groups : key => group if length(group.parents) == 0 }
  through_0 = toset(keys(local.level_0))
  level_1   = { for key, group in var.groups : key => group if length(group.parents) > 0 && alltrue([for parent in group.parents : contains(local.through_0, parent)]) }
  through_1 = setunion(local.through_0, toset(keys(local.level_1)))
  level_2   = { for key, group in var.groups : key => group if length(group.parents) > 0 && alltrue([for parent in group.parents : contains(local.through_1, parent)]) && anytrue([for parent in group.parents : contains(keys(local.level_1), parent)]) }
  through_2 = setunion(local.through_1, toset(keys(local.level_2)))
  level_3   = { for key, group in var.groups : key => group if length(group.parents) > 0 && alltrue([for parent in group.parents : contains(local.through_2, parent)]) && anytrue([for parent in group.parents : contains(keys(local.level_2), parent)]) }
  through_3 = setunion(local.through_2, toset(keys(local.level_3)))
  level_4   = { for key, group in var.groups : key => group if length(group.parents) > 0 && alltrue([for parent in group.parents : contains(local.through_3, parent)]) && anytrue([for parent in group.parents : contains(keys(local.level_3), parent)]) }
  through_4 = setunion(local.through_3, toset(keys(local.level_4)))
}

resource "authentik_group" "level_0" {
  for_each = local.level_0

  name         = each.value.name
  is_superuser = each.value.is_superuser
  roles        = compact([for role in each.value.roles : try(var.role_ids[role], null)])

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "level_1" {
  for_each = local.level_1

  name         = each.value.name
  is_superuser = each.value.is_superuser
  parents      = compact([for parent in each.value.parents : try(authentik_group.level_0[parent].id, null)])
  roles        = compact([for role in each.value.roles : try(var.role_ids[role], null)])

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "level_2" {
  for_each = local.level_2

  name         = each.value.name
  is_superuser = each.value.is_superuser
  parents = compact([for parent in each.value.parents : try(
    authentik_group.level_1[parent].id,
    authentik_group.level_0[parent].id,
    null,
  )])
  roles = compact([for role in each.value.roles : try(var.role_ids[role], null)])

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "level_3" {
  for_each = local.level_3

  name         = each.value.name
  is_superuser = each.value.is_superuser
  parents = compact([for parent in each.value.parents : try(
    authentik_group.level_2[parent].id,
    authentik_group.level_1[parent].id,
    authentik_group.level_0[parent].id,
    null,
  )])
  roles = compact([for role in each.value.roles : try(var.role_ids[role], null)])

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "level_4" {
  for_each = local.level_4

  name         = each.value.name
  is_superuser = each.value.is_superuser
  parents = compact([for parent in each.value.parents : try(
    authentik_group.level_3[parent].id,
    authentik_group.level_2[parent].id,
    authentik_group.level_1[parent].id,
    authentik_group.level_0[parent].id,
    null,
  )])
  roles = compact([for role in each.value.roles : try(var.role_ids[role], null)])

  lifecycle {
    ignore_changes = [users]
  }
}

output "ids" {
  value = merge(
    { for key, group in authentik_group.level_0 : key => group.id },
    { for key, group in authentik_group.level_1 : key => group.id },
    { for key, group in authentik_group.level_2 : key => group.id },
    { for key, group in authentik_group.level_3 : key => group.id },
    { for key, group in authentik_group.level_4 : key => group.id },
  )

  precondition {
    condition     = length(local.through_4) == length(var.groups)
    error_message = "Group hierarchy must be acyclic and no more than five levels deep."
  }
}

output "groups" {
  value = merge(
    { for key, group in authentik_group.level_0 : key => group },
    { for key, group in authentik_group.level_1 : key => group },
    { for key, group in authentik_group.level_2 : key => group },
    { for key, group in authentik_group.level_3 : key => group },
    { for key, group in authentik_group.level_4 : key => group },
  )
}
