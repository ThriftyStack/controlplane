# Authentik identity

Manages Authentik groups, OAuth2 and proxy applications, entitlements, policy
bindings, and the `oke` proxy outpost via the Authentik API. Does not deploy
the Authentik containers or the outpost workload.

Group names follow [ADR-0001](https://www.notion.so/400972443c708191aafbc0a9a1f7dc8a):
`homelab-users` and `homelab-admins`. Proxmox consumes the entitlement name
`proxmox-admins` from the `groups` claim. Longhorn is a proxy provider on
outpost `oke`.

`adoption_ids` in `terraform.tfvars` holds the live Proxmox entitlement pbm
uuid, the Longhorn proxy provider numeric pk, and the `oke` outpost uuid.
Imports use those values for objects that already exist. Longhorn has no
entitlements. Its external host is `https://longhorn.oci.devoops.uk`, and the
`oke` outpost `authentik_host` is `https://auth.devoops.uk`.

Auth chain: projected service account token → Vault Kubernetes auth role
`authentik-tofu` on mount `kubernetes-management` → Vault `infra/authentik`
key `tofu-api-token` → Authentik API.

Crossplane Workspace `authentik` applies this directory. Local validation is
`make check`. The Workspace sets `vault_addr` to the in-cluster management
Vault. State stays in the GCS prefix `controlplane/authentik`.
