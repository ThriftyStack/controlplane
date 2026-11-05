# Application import ids are slugs. Provider pks and entitlement/outpost uuids
# are not derivable from names; adoption_ids in terraform.tfvars supplies them.
# The entitlement id is the pbm uuid, the proxy provider id is the decimal pk,
# and the outpost id is the outpost uuid.
# The scope-mapping id is the mapping pk (a uuid) supplied by
# adoption_ids.entitlement_groups_scope.

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

import {
  to = module.oauth2_apps.authentik_property_mapping_provider_scope.entitlement_groups[0]
  id = var.adoption_ids.entitlement_groups_scope
}
