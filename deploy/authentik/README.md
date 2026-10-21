# Apply Authentik with Crossplane

The management cluster applies [`authentik/`](../../authentik/) through the
Workspace in this directory. OpenTofu state stays in the GCS prefix
`controlplane/authentik`.

## Secrets

Create both secrets in `crossplane-system` before the Workspace can run.
Use a GitHub credential that can read this private repository, and a GCP key
that can read Secret Manager and the state bucket.

```sh
kubectl create secret generic authentik-git-credentials \
  --namespace crossplane-system \
  --from-file=.git-credentials=git-credentials
kubectl create secret generic authentik-gcp-credentials \
  --namespace crossplane-system \
  --from-file=credentials=gcp-credentials.json
```

`git-credentials` has one line. Copy `git-credentials.example` and replace the
placeholder. Do not commit the filled file.

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
