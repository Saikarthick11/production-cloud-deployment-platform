# From a code push to a running registry image

```text
Push to main → AMD64 and ARM64 tests/build/smoke checks/Trivy scans
             → publish both scanned images to GHCR
             → publish a combined multi-platform tag
             → commit the tag into gitops/values-local.yaml
             → Argo CD syncs Git → Kubernetes pulls its native image
```

The two `verify` jobs use native Ubuntu runners. Both must pass before `publish`
runs. Each image is transferred as a workflow artifact, so publishing does not
rebuild unscanned content. Architecture-specific tags end in `-amd64` or `-arm64`;
the combined `sha-<source-commit>` tag points to both. Existing older tags may
contain only AMD64 images.

`promote` runs after publication with `contents: write`. It checks that `main`
still equals the source commit, updates only three image settings, and commits
as the configured project identity, Saikarthick11. The message identifies the
automated deployment. It uses GitHub's short-lived token, not a personal token.
The script validates its inputs and preserves replicas and logging settings.

GitHub does not trigger another push workflow for a commit made using this
workflow token. That prevents a promotion loop. Argo still sees that commit when
it polls Git. The promotion commit itself therefore has no separate CI run;
its referenced source commit has the passing run. See GitHub's
[workflow triggering rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).

A newer source commit skips an older promotion. If another push races after
checkout, the final ordinary push is rejected rather than overwriting it. A
failed publication or scan cannot reach promotion. A stale/failed run may leave
unused images in GHCR; it does not advance the deployment settings.

## Registry access

The project image is readable anonymously, so Kubernetes needs no registry
password or pull Secret. No package visibility is changed by this workflow.
If the package is later made private, configure a narrowly scoped image-pull
Secret outside Git before deploying; do not paste a credential into values files.

The combined tag is source-specific but GHCR tags are technically mutable. A
future hardening step is promoting an immutable manifest digest instead.

## Verify a delivery

Open GitHub Actions and confirm both architecture checks, publication, and
promotion passed. Look for the `Deploy scanned image sha-...` commit on `main`.
From the local project folder:

```bash
git pull --ff-only
kubectl --kubeconfig .local/kubeconfig -n argocd get application cloud-platform-gitops
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-gitops get deployment cloud-platform-gitops -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-gitops get pods -o wide
```

Wait for `Synced` and `Healthy`. The running Deployment should reference GHCR,
not `cloud-platform:gitops-v1`. Kubernetes chooses ARM64 on this Mac's kind node.
No `kind load` step is required for new published images. Docker Desktop and the
cluster must be running for Argo to deploy; otherwise it catches up on restart.

If desired, request a fresh Git check without applying workload YAML:

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd annotate application cloud-platform-gitops argocd.argoproj.io/refresh=hard --overwrite
```

The workflow does not connect from GitHub into your laptop. Argo pulls Git, and
Kubernetes pulls the image. Reopen the app's port-forward if its Pod changes.

## Limits and recovery

This learning workflow promotes successful main builds directly. A team would
usually protect main and review a separate deployment PR. Argo can apply chart
or configuration edits on main before CI finishes; the publishing gate controls
automatic image promotion, not all possible Git edits.

To recover from bad application behavior, revert the source change and let CI
produce a new tested image. A manually restored image tag on main can be replaced
by the next successful promotion; pause the workflow before a manual image rollback
if you need to hold that version. A failed readiness probe also leaves Argo degraded
and must be investigated rather than treated as successful delivery.

If branch protection later rejects automated commits, switch promotion to a
reviewed pull request rather than bypassing the protection.
