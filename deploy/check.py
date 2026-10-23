#!/usr/bin/env python3

import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
DEPLOY = ROOT / "deploy" / "authentik"
VERSION = (ROOT / ".opentofu-version").read_text().strip()
IMAGE = (
    "ghcr.io/opentofu/opentofu:"
    + VERSION
    + "@sha256:22cb52f6c5bf5c72a48a8f56d993d8df3e9462b1cdfb5db7e77143c87e8d159f"
)


def load(name):
    text = (DEPLOY / name).read_text()
    if "ghp_" in text or "github_pat_" in text:
        raise SystemExit(f"{name} contains a GitHub token")
    docs = list(yaml.safe_load_all(text))
    if any(doc is None for doc in docs):
        raise SystemExit(f"{name} has an empty document")
    return docs


def main():
    runtime, provider = load("runtime.yaml")
    (provider_config,) = load("providerconfig.yaml")
    (workspace,) = load("workspace.yaml")
    example = (DEPLOY / "git-credentials.example").read_text().strip()

    init = runtime["spec"]["deploymentTemplate"]["spec"]["template"]["spec"][
        "initContainers"
    ][0]
    if init["image"] != IMAGE:
        raise SystemExit(f"OpenTofu image {init['image']} does not match {IMAGE}")

    if provider["spec"]["package"] != "xpkg.upbound.io/upbound/provider-opentofu:v1.1.10":
        raise SystemExit("provider package pin changed")
    if provider["spec"]["runtimeConfigRef"]["name"] != runtime["metadata"]["name"]:
        raise SystemExit("Provider runtimeConfigRef does not match the runtime")

    filenames = [item["filename"] for item in provider_config["spec"]["credentials"]]
    if filenames != [".git-credentials", "gcp-credentials.json"]:
        raise SystemExit(f"credential filenames {filenames}")

    spec = workspace["spec"]
    module = spec["forProvider"]
    if spec["deletionPolicy"] != "Orphan":
        raise SystemExit("Workspace deletionPolicy must stay Orphan")
    if spec["managementPolicies"] != ["Observe", "Create", "Update"]:
        raise SystemExit("Workspace must not gain Delete")
    if module["module"] != "git::https://github.com/ThriftyStack/controlplane.git?ref=main":
        raise SystemExit("Workspace module source changed")
    if module["entrypoint"] != "authentik" or module["remotePullPolicy"] != "Always":
        raise SystemExit("Workspace must track authentik on main")
    env = {item["name"]: item["value"] for item in module["env"]}
    if env.get("GOOGLE_APPLICATION_CREDENTIALS") != "gcp-credentials.json":
        raise SystemExit("GCP credentials path changed")
    vault = {item["key"]: item["value"] for item in module["vars"]}
    if vault.get("vault_addr") != "https://vault.vault.svc:8200":
        raise SystemExit("in-cluster Vault address changed")
    if any("vault_token" in key or "vault-token" in str(value) for key, value in vault.items()):
        raise SystemExit("Workspace vars must not reference a static Vault token")
    if "<token>" not in example or example.startswith("https://x-access-token:@"):
        raise SystemExit("git credential example lost its placeholder")

    assert_vault_kubernetes_auth(runtime)
    assert_no_static_vault_token(
        DEPLOY / "runtime.yaml",
        DEPLOY / "providerconfig.yaml",
        DEPLOY / "workspace.yaml",
        DEPLOY / "README.md",
        ROOT / "authentik" / "providers.tf",
        ROOT / "authentik" / "variables.tf",
        ROOT / "authentik" / "versions.tf",
    )

    print("deploy checks passed")


def assert_vault_kubernetes_auth(runtime):
    pod = runtime["spec"]["deploymentTemplate"]["spec"]["template"]["spec"]
    sa = runtime["spec"]["serviceAccountTemplate"]["metadata"]["name"]
    if sa != "provider-opentofu" or pod.get("serviceAccountName") != "provider-opentofu":
        raise SystemExit("provider pod service account must be provider-opentofu")

    auth = next((item for item in pod["volumes"] if item["name"] == "vault-auth"), None)
    if auth is None or "projected" not in auth:
        raise SystemExit("vault-auth projected volume missing")
    sources = auth["projected"]["sources"]
    token = next(
        (item["serviceAccountToken"] for item in sources if "serviceAccountToken" in item),
        None,
    )
    if token is None:
        raise SystemExit("vault-auth service account token missing")
    if token.get("audience") != "vault://crossplane-system/authentik-tofu":
        raise SystemExit("vault-auth audience mismatch")
    if token.get("path") != "token" or int(token.get("expirationSeconds", 0)) != 3600:
        raise SystemExit("vault-auth token path or expiration changed")

    container = next(item for item in pod["containers"] if item["name"] == "package-runtime")
    mount = next((item for item in container["volumeMounts"] if item["name"] == "vault-auth"), None)
    if (
        mount is None
        or mount.get("mountPath") != "/var/run/vault-auth"
        or mount.get("readOnly") is not True
    ):
        raise SystemExit("vault-auth must be mounted read-only at /var/run/vault-auth")

    providers = (ROOT / "authentik" / "providers.tf").read_text()
    if 'path = "auth/kubernetes-management/login"' not in providers:
        raise SystemExit("Vault provider must log in through kubernetes-management")
    if 'role = "authentik-tofu"' not in providers or 'try(file("/var/run/vault-auth/token"), "")' not in providers:
        raise SystemExit("Vault Kubernetes login parameters changed")
    if 'provider "google"' in providers or "hashicorp/google" in (ROOT / "authentik" / "versions.tf").read_text():
        raise SystemExit("google provider is unused")


def assert_no_static_vault_token(*paths):
    for path in paths:
        text = path.read_text()
        if "vault-token" in text or "vault_token_secret" in text:
            raise SystemExit(f"{path.relative_to(ROOT)} still references a static Vault token")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        print(f"deploy checks failed: {exc}", file=sys.stderr)
        sys.exit(1)
