# Authentik identity

Manages Authentik groups, OAuth2 and proxy applications, entitlements, policy
bindings, and the `oke` proxy outpost via the Authentik API. Does not deploy
the Authentik containers or the outpost workload.

Group names follow [ADR-0001](https://www.notion.so/400972443c708191aafbc0a9a1f7dc8a):
`homelab-users` and `homelab-admins`. Proxmox consumes the entitlement name
`proxmox-admins` from the `groups` claim. Longhorn is a proxy provider on
outpost `oke`.

`adoption_ids` in `terraform.tfvars` holds the live Proxmox entitlement pbm
uuid, the Grafana, Proxmox, and Vault OAuth2 provider numeric pks, the
Longhorn proxy provider numeric pk, the `oke` outpost uuid, and the groups
scope-mapping pk for the live mapping named Homelab application entitlement
groups. Grafana, Proxmox, Vault, and Longhorn applications import by slug.
Imports use those values for objects that already exist. Longhorn has no
entitlements. Its external host is `https://longhorn.oci.devoops.uk`, and the
`oke` outpost `authentik_host` is `https://auth.devoops.uk`.

Auth chain: projected service account token (audience `vault-oke`) → Vault
JWT role `crossplane-system_provider-opentofu` on mount `jwt-management` →
Vault `infra/authentik` key `tofu-api-token` → Authentik API.

Crossplane Workspace `authentik` applies this directory. Local validation is
`make check`. The Workspace sets `vault_addr` to `https://vault.devoops.uk`.
State stays in the GCS prefix `controlplane/authentik`.
