# Application import ids are slugs. Provider pks and entitlement/outpost uuids
# are not derivable from names; adoption_ids supplies them. An unset
# adoption_ids fails the plan, so the Workspace cannot create or destroy the
# live objects until those keys are filled in.

import {
  to = module.oauth2_apps.authentik_application_entitlement.this["proxmox_admins"]
  id = var.adoption_ids.proxmox_admins_entitlement
}

import {
  to = module.proxy_apps.authentik_provider_proxy.this["longhorn"]
  id = var.adoption_ids.longhorn_provider
}

import {
  to = module.proxy_apps.authentik_application.this["longhorn"]
  id = "longhorn"
}

import {
  for_each = var.proxy_entitlement_adoption_ids
  to       = module.proxy_apps.authentik_application_entitlement.this[each.key]
  id       = each.value
}

check "proxy_entitlements_are_adopted" {
  assert {
    condition = alltrue([
      for key in distinct(flatten([for app in values(var.proxy_apps) : keys(app.entitlements)])) :
      contains(keys(var.proxy_entitlement_adoption_ids), key) && trimspace(var.proxy_entitlement_adoption_ids[key]) != ""
    ])
    error_message = "Each proxy entitlement needs its live pbm uuid in proxy_entitlement_adoption_ids."
  }
}

import {
  to = module.proxy_apps.authentik_outpost.this["oke"]
  id = var.adoption_ids.oke_outpost
}
