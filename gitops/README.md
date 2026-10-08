# GitOps with Argo CD

Argo CD watches the Helm chart and `gitops/values-local.yaml` on GitHub's `main`
branch, renders Kubernetes objects, and reconciles them with the local cluster.
Git is the desired state; direct cluster edits are corrected by self-healing.

This lesson uses a local ARM-compatible image built from the updated Alpine
Dockerfile. It is not the AMD64 image published by CI. New CI images are not
automatically promoted: registry access, compatible image publishing, and image
tag promotion remain separate work. Configuration changes in Git do deploy
automatically. Keep this distinction clear in demonstrations.

## Files

- `namespace.yaml`: creates the dedicated `cloud-platform-gitops` namespace.
- `project.yaml`: restricts the Application to this Git repository, namespace,
  and four required resource kinds. Argo CD's installation itself has broader
  cluster permissions; this is a local learning setup.
- `application.yaml`: connects the Git source and chart to the cluster, enabling
  automatic sync, pruning, and self-healing.
- `values-local.yaml`: selects the local image, replica count, and log level.

Argo uses Helm to render templates, but manages the resources itself. This app
will not appear as a release in `helm list`; use Argo's UI or Application status.
Do not run `helm upgrade` against these resources. Earlier Kubernetes and Helm
examples remain in their own namespaces.

## Recreate setup (already performed on the original machine)

Run from the project root with Docker Desktop and the kind cluster running:

```bash
docker build -t cloud-platform:gitops-v1 .
.tools/kind load docker-image cloud-platform:gitops-v1 --name cloud-platform
mkdir -p .local
curl -fL https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.4/manifests/install.yaml -o .local/argocd-install.yaml
kubectl --kubeconfig .local/kubeconfig create namespace argocd --dry-run=client -o yaml | kubectl --kubeconfig .local/kubeconfig apply -f -
kubectl --kubeconfig .local/kubeconfig apply --server-side -n argocd -f .local/argocd-install.yaml
kubectl --kubeconfig .local/kubeconfig -n argocd rollout status deployment/argocd-repo-server --timeout=300s
kubectl --kubeconfig .local/kubeconfig -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
kubectl --kubeconfig .local/kubeconfig apply -f gitops/namespace.yaml -f gitops/project.yaml -f gitops/application.yaml
```

The installation is pinned to Argo CD v3.5.4. Its manifests stay in ignored
`.local/`. The Application needs these project files pushed to GitHub, because
Argo reads GitHub, not your laptop's working folder. The Application and AppProject
are bootstrapped manually; Argo manages the chart's four resources, not its own
bootstrap files.

## Inspect and open

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd get application cloud-platform-gitops
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-gitops get pods,services
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-gitops port-forward service/cloud-platform-gitops 8004:80 --address 127.0.0.1
```

Keep forwarding running and open <http://127.0.0.1:8004/>. Expect Application
status `Synced` and health `Healthy` after reconciliation. `Synced` means the
rendered resources match Git; `Healthy` reflects resource health checks, not a
full application test suite.

In another terminal, expose the Argo UI:

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd port-forward service/argocd-server 8080:443 --address 127.0.0.1
```

Open <https://127.0.0.1:8080/>. This local installation uses a self-signed TLS
certificate, so the browser may ask you to accept it for this local address.
The username is `admin`. Retrieve the generated password in your own terminal:

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 --decode
```

Do not commit or share that password. Stop a tunnel with Ctrl+C; the workload
continues running. After Docker Desktop restarts, wait for the cluster and Argo
Pods to recover, then reopen the tunnels.

## Learn automatic deployment

1. Change `logLevel: info` to `logLevel: debug` in `gitops/values-local.yaml`.
2. Commit and push that file to `main`.
3. Argo polls Git periodically; give it several minutes, or request an immediate
   refresh with the command below.
4. Watch the Application and check the Pod's environment variable.

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd annotate application cloud-platform-gitops argocd.argoproj.io/refresh=hard --overwrite
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-gitops exec deployment/cloud-platform-gitops -- printenv UVICORN_LOG_LEVEL
```

The Helm chart's configuration checksum changes, causing a new Pod to start.
The refresh command only requests a recheck; it does not deploy local files.
Revert the Git change and push to restore `info`. Restart port-forward if its
selected Pod was replaced.

Argo does not wait for the repository's CI run before syncing a `main` configuration
change. Protect `main` with reviewed pull requests and required checks for a team
workflow. This demo does not configure branch protection.

## Learn drift correction

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-gitops scale deployment/cloud-platform-gitops --replicas=2
```

Argo should restore one replica because Git still requests one. That is
self-healing. To keep two replicas, change the Git values file instead.
Each Pod has its own in-memory metric counter.

`prune: true` removes previously managed resources removed from Git.
`allowEmpty: false` guards against automatically pruning an entirely empty app.
This Application intentionally has no deletion finalizer: deleting the
Application alone stops its management but leaves deployed resources behind.
For full demo cleanup, delete the Application first, then its workload namespace:

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd delete application cloud-platform-gitops
kubectl --kubeconfig .local/kubeconfig delete namespace cloud-platform-gitops
```

Keep Argo installed for later practice. Deleting the whole kind cluster removes
Argo and all earlier local examples too.

## Troubleshooting

- `ImagePullBackOff`: build/load `cloud-platform:gitops-v1` into this kind cluster.
- `ComparisonError`: inspect `kubectl --kubeconfig .local/kubeconfig -n argocd describe application cloud-platform-gitops`.
- `OutOfSync`: check sync operation errors, Git availability, and Argo Pod health.
- Git changed but nothing deployed: check the pushed branch and values path.
- Do not reuse the AMD64 GHCR tag on this ARM cluster without arranging compatible
  image execution and registry access.

Reference: [Argo CD getting started](https://argo-cd.readthedocs.io/en/stable/getting_started/).
