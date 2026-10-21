# Repository Guidance

## Philosophy

This homelab deliberately reproduces production- and enterprise-grade quality
and realistic operational complexity on a small, inexpensive infrastructure
footprint. Constrain cost, capacity, and scale, not correctness, security,
isolation, observability, recovery, automation, or maintainability.

## Simplicity Gate

All code changes must follow Ponytail at full intensity. Stop at the first option
that preserves the required operational guarantees:

1. do not build speculative behavior;
2. reuse an existing repository pattern;
3. use the language, provider, or platform's native capability;
4. use an already-installed dependency;
5. write the minimum new code and the smallest regression check.

## Agent Workflow

Before changing code:

1. Inspect the working tree and preserve unrelated user changes.
2. Read the root README, the changed area's README, and every relevant call site.
3. Treat each top-level area as an independent state and deployment boundary.
4. Check the `docs` repository when behavior crosses repositories.

Agents may run non-live validation without asking:

```sh
make -C <area> check
```

Do not run `plan`, `apply`, `destroy`, `output`, or `import` against live
infrastructure unless the user explicitly requests that operation. Never commit
state, plan files, `.terraform/`, generated credentials, or `.env` files.

## Ownership

- This repository owns Authentik **identity configuration** (groups, apps,
  entitlements, bindings).
- The management cluster Crossplane applies that configuration. Do not apply
  it from a workstation.
- `ansible/deployments` owns the Authentik **runtime stack**.
- `terraform` owns the Authentik **VM, DNS, and tunnel**.
- Do not put Authentik identity OpenTofu back into `terraform/` or `bootstrap/`.

## Commits

Use Conventional Commits. The body explains **why**, not what.
