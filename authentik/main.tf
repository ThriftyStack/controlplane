module "roles" {
  source = "./modules/roles"

  roles = var.roles
}

module "groups" {
  source = "./modules/groups"

  groups   = var.groups
  role_ids = module.roles.ids
}

module "oauth2_apps" {
  source = "./modules/oauth2_apps"

  apps        = var.oauth2_apps
  vault_mount = var.vault_secret_mount
}

module "proxy_apps" {
  source = "./modules/proxy_apps"

  apps     = var.proxy_apps
  outposts = var.outposts
}

module "policies" {
  source = "./modules/policies"

  application_ids       = module.oauth2_apps.application_ids
  bindings              = var.bindings
  entitlement_ids       = merge(module.oauth2_apps.entitlement_ids, module.proxy_apps.entitlement_ids)
  group_ids             = module.groups.ids
  policies              = var.policies
  proxy_application_ids = module.proxy_apps.application_ids
}
