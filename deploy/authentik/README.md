# Apply Authentik with Crossplane

The management cluster applies [`authentik/`](../../authentik/) through the
Workspace in this directory. OpenTofu state stays in the GCS prefix
`controlplane/authentik`.

## Secrets

This repository is public. Create both secrets in `crossplane-system` before
the Workspace can run. `authentik-git-credentials` is mounted as
`.git-credentials` and can be created from an empty file. The GCP key reads
the state bucket `project-d10f7f85-317f-426a-a46-tofu-state`.

The provider pod runs as service account `provider-opentofu` and logs in to
the management Vault with the projected token at `/var/run/vault-auth/token`.

```sh
touch git-credentials
kubectl create secret generic authentik-git-credentials \
  --namespace crossplane-system \
  --from-file=.git-credentials=git-credentials
kubectl create secret generic authentik-gcp-credentials \
  --namespace crossplane-system \
  --from-file=credentials=gcp-credentials.json
```

`git-credentials.example` is the shape of a credential line if one is required
later. Do not commit a filled file.

## Argo CD

The platform Applications source only `ThriftyStack/platform`. Register this
directory on the management AppProject, then add an Application.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: controlplane-authentik
  namespace: argocd
spec:
  project: management
  source:
    repoURL: https://github.com/ThriftyStack/controlplane.git
    targetRevision: main
    path: deploy/authentik
    directory:
      recurse: false
  destination:
    server: https://kubernetes.default.svc
    namespace: crossplane-system
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

`directory.recurse` stays false so this README and the credential example are
not applied. Argo CD applies `runtime.yaml`, `providerconfig.yaml`, and
`workspace.yaml`.
