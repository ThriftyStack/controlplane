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
  to = module.proxy_apps.authentik_outpost.this["oke"]
  id = var.adoption_ids.oke_outpost
}
