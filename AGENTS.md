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
4. Read the relevant Notion page under Documentation in Notion before
   changing behavior, then update that page in the same task.

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
- `ThriftyStack/platform` owns the Authentik **runtime** Helm chart
  (`infrastructure/charts/authentik`, ADR-0007).
- `terraform` owns Authentik **DNS and tunnel** targets (not the retired VM).
- Do not put Authentik identity OpenTofu back into `terraform/` or `bootstrap/`.

## Commits

Use Conventional Commits. The body explains **why**, not what.

## Documentation in Notion

Notion is the source of truth for ThriftyStack documentation. Read the
relevant page below before you change behavior it describes. In the same
task, update that page, or add one under the right section, and keep its
gray "Last updated by" line current with your name, what changed, and the
date. Record a new decision as the next ADR page under Architectural
Decision Records. Never put secrets, tokens, passwords, or other
credentials in Notion. Leave the legacy `ThriftyStack/docs` GitHub
repository unchanged.

Pages for this repository:

- [ThriftyStack Docs](https://www.notion.so/400972443c7081fd83efd3e8710fc9a6)
- [Authentik](https://www.notion.so/400972443c7081d2885dcba7e839fedf)
- [Architectural Decision Records](https://www.notion.so/400972443c708169b262e47f7c9c56e0)
- [ADR-0001: Authentik is the human identity and access source of truth](https://www.notion.so/400972443c708191aafbc0a9a1f7dc8a)
- [ADR-0002: Keep Google OIDC and local credentials on critical systems](https://www.notion.so/400972443c708187af2fc5faf74eb8cf)
- [ADR-0003: Map Authentik groups and roles onto Google SSO identities](https://www.notion.so/400972443c70811d9da6ea12ea8e5478)

Share the ThriftyStack Docs root with the Notion account that connects.
The MCP server opens only pages that account can open.

### Notion MCP setup

The hosted server is remote OAuth at `https://mcp.notion.com/mcp`. The
committed project files store that URL and no access tokens. Each person
signs in once per tool, and that sign-in stays on their machine.

Cursor reads `.cursor/mcp.json`. Open Customize in the sidebar, enable
Notion, and finish the OAuth flow. Cursor has no shell login for this
server. To check the connection, confirm Notion is enabled under Customize
and that its tools are listed. When the connection fails, open the Output
panel, choose MCP Logs, and read the Notion error.

Claude Code reads `.mcp.json`. The Notion entry sets `"type": "http"`.
From this repository, run `claude` and approve the project MCP server.
Then run `claude mcp login notion` and finish the browser OAuth flow.
Check with `claude mcp list`. `✔ Connected` means the server is signed in.
`! Needs authentication` means the login is still required. `/mcp` inside
a Claude Code session shows the same status.

Codex reads the `[mcp_servers.notion]` table in `.codex/config.toml`.
Codex loads that file only after you trust the project. Run
`codex mcp login notion` and finish the browser OAuth flow. Check with
`codex mcp list`. In the Codex TUI, `/mcp` lists the active servers.

Cursor, Claude Code, and Codex all load these project files.
