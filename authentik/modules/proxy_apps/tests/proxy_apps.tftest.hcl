mock_provider "authentik" {
  mock_data "authentik_flow" {
    defaults = {
      id = "flow-1"
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = "7"
    }
  }

  mock_resource "authentik_application" {
    defaults = {
      uuid = "app-uuid"
    }
  }

  mock_resource "authentik_outpost" {
    defaults = {
      id = "outpost-uuid"
    }
  }
}

variables {
  outposts = {}
}

run "adopts_longhorn_and_oke" {
  command = plan

  variables {
    apps = {
      longhorn = {
        name          = "Longhorn"
        group         = "Infrastructure"
        external_host = "https://longhorn.k8s.devoops.uk"
      }
    }
    outposts = {
      oke = {
        name      = "oke"
        providers = ["longhorn"]
      }
    }
  }

  assert {
    condition = alltrue([
      authentik_provider_proxy.this["longhorn"].name == "Longhorn",
      authentik_provider_proxy.this["longhorn"].external_host == "https://longhorn.k8s.devoops.uk",
      authentik_provider_proxy.this["longhorn"].authorization_flow == "flow-1",
      authentik_provider_proxy.this["longhorn"].invalidation_flow == "flow-1",
      authentik_application.this["longhorn"].slug == "longhorn",
      authentik_application.this["longhorn"].group == "Infrastructure",
      authentik_application.this["longhorn"].protocol_provider == 7,
      authentik_outpost.this["oke"].name == "oke",
      authentik_outpost.this["oke"].protocol_providers == tolist([7]),
      length(authentik_application_entitlement.this) == 0,
    ])
    error_message = "Longhorn proxy, its application, and the oke outpost must keep the adopted names and hosts."
  }
}

run "keeps_entitlement_name" {
  command = plan

  variables {
    apps = {
      longhorn = {
        name          = "Longhorn"
        group         = "Infrastructure"
        external_host = "https://longhorn.k8s.devoops.uk"
        entitlements = {
          longhorn_admins = "longhorn-admins"
        }
      }
    }
  }

  assert {
    condition     = authentik_application_entitlement.this["longhorn_admins"].name == "longhorn-admins"
    error_message = "Entitlement names must be copied unchanged. Consumers match the string, not the configuration key."
  }
}
