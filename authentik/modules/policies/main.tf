terraform {
  required_version = ">= 1.12.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.1"
    }
  }
}

variable "application_ids" {
  type = map(string)
}

variable "entitlement_ids" {
  type = map(string)
}

variable "group_ids" {
  type = map(string)
}

variable "policies" {
  type = map(object({
    name              = string
    expression        = string
    execution_logging = optional(bool, false)
  }))
}

variable "bindings" {
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
}

locals {
  targets = merge(
    { for key, id in var.application_ids : "oauth2_app:${key}" => id },
    { for key, id in var.entitlement_ids : "entitlement:${key}" => id },
  )
}

resource "authentik_policy_expression" "this" {
  for_each = var.policies

  name              = each.value.name
  expression        = each.value.expression
  execution_logging = each.value.execution_logging
}

resource "authentik_policy_binding" "this" {
  for_each = var.bindings

  target         = local.targets["${each.value.target_type}:${each.value.target}"]
  group          = each.value.subject_type == "group" ? var.group_ids[each.value.subject] : null
  policy         = each.value.subject_type == "policy" ? authentik_policy_expression.this[each.value.subject].id : null
  order          = each.value.order
  enabled        = each.value.enabled
  negate         = each.value.negate
  failure_result = each.value.failure_result
  timeout        = each.value.timeout
}

output "policies" {
  value = authentik_policy_expression.this
}

output "bindings" {
  value = authentik_policy_binding.this
}
