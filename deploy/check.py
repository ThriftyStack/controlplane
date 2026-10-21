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
    if "<token>" not in example or example.startswith("https://x-access-token:@"):
        raise SystemExit("git credential example lost its placeholder")

    print("deploy checks passed")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        print(f"deploy checks failed: {exc}", file=sys.stderr)
        sys.exit(1)
