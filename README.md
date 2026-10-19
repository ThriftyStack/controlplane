# Control plane

OpenTofu configuration for estate control-plane services that are not host
bootstraps and are not general infrastructure roots.

| Area | Purpose | Local validation |
| --- | --- | --- |
| [`authentik/`](authentik/) | Authentik groups, entitlements, and OAuth2 applications | `make -C authentik check` |

Host runtime for Authentik (Compose, TLS, secrets wiring) lives in
[`ansible/deployments`](https://github.com/ThriftyStack/ansible). Proxmox VM,
DNS, and tunnel resources stay in
[`terraform`](https://github.com/ThriftyStack/terraform). Management-cluster
day-0 stays in [`bootstrap`](https://github.com/ThriftyStack/bootstrap).

## Authentik identity

[`authentik/`](authentik/) is the source of truth for ADR-0001 groups
(`homelab-users`, `homelab-admins`) and the Grafana, Vault, and Proxmox OIDC
applications. Ansible must not reconcile those objects.

### Prerequisites

1. Authentik is up at `https://auth.devoops.uk` (ansible `authentik.yml`).
2. Complete initial setup once, create an API token, and store it:

   ```bash
   vault kv patch infra/authentik tofu-api-token='<token>'
   ```

3. Seed OIDC client IDs and secrets (IDs must match relying-party config):

   ```bash
   vault kv put infra/authentik/clients \
     grafana-client-id=grafana grafana="$(openssl rand -hex 32)" \
     vault-client-id=vault vault="$(openssl rand -hex 32)"
   vault kv patch infra/proxmox-oidc \
     authentik-client-id=proxmox authentik="$(openssl rand -hex 32)"
   ```

4. Application Default Credentials that can read the Vault token from Secret
   Manager, plus LAN, WARP, or NetBird reachability to Authentik.

### Operate

```sh
make -C authentik check
make -C authentik plan
make -C authentik apply
```

State is GCS under prefix `controlplane/authentik`. OpenTofu is pinned in
[`.opentofu-version`](.opentofu-version).
