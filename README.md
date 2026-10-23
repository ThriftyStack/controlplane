# controlplane

# Control plane

OpenTofu configuration for estate control-plane services that are not host
bootstraps and are not general infrastructure roots.

| Area | Purpose | Local validation |
| --- | --- | --- |
| [`authentik/`](authentik/) | Authentik groups, entitlements, and OAuth2 applications | `make -C authentik check` |
| [`deploy/authentik/`](deploy/authentik/) | Crossplane Workspace that applies `authentik/` | `make -C deploy check` |

Host runtime for Authentik (Compose, TLS, secrets wiring) lives in
[`ansible/deployments`](https://github.com/ThriftyStack/ansible). Proxmox VM,
DNS, and tunnel resources stay in
[`terraform`](https://github.com/ThriftyStack/terraform). Management-cluster
day-0 stays in [`bootstrap`](https://github.com/ThriftyStack/bootstrap).

## Authentik identity

[`authentik/`](authentik/) is the source of truth for the
[ADR-0001](https://www.notion.so/400972443c708191aafbc0a9a1f7dc8a) groups
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

4. Create the two secrets in `crossplane-system` named by
   [`deploy/authentik/providerconfig.yaml`](deploy/authentik/providerconfig.yaml).
   This repository is public, so `authentik-git-credentials` can be mounted
   from an empty file. The GCP secret is the key the Workspace uses for the
   GCS state backend.
5. Argo CD on the management cluster sources `deploy/authentik`. The management
   AppProject must allow `https://github.com/ThriftyStack/controlplane.git`.

### Operate

Crossplane Workspace `authentik` applies this root from inside the management
cluster. Local validation stays:

```sh
make -C authentik check
make -C deploy check
```

State is GCS under prefix `controlplane/authentik`. OpenTofu is pinned in
[`.opentofu-version`](.opentofu-version). The provider image ships an older
CLI, and [`deploy/authentik/runtime.yaml`](deploy/authentik/runtime.yaml)
replaces it with that pin before tofu runs.
