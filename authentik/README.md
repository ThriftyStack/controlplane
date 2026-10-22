# Authentik identity

Manages Authentik groups, OAuth2 applications, entitlements, and policy bindings
via the Authentik API. Does not deploy the Authentik containers.

Group names follow [ADR-0001](https://www.notion.so/400972443c708191aafbc0a9a1f7dc8a):
`homelab-users` and `homelab-admins`.

Auth chain: ADC → Secret Manager Vault token → Vault `infra/authentik` key
`tofu-api-token` → Authentik API.

Crossplane Workspace `authentik` applies this directory. Local validation is
`make check`. The Workspace sets `vault_addr` to the in-cluster Vault service.
