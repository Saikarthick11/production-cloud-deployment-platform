# Helm: package the Kubernetes configuration

Run commands from the project root. Docker Desktop and the `cloud-platform` kind
cluster must be running, with `cloud-platform:k8s-v1` loaded as described in
`k8s/README.md`. Helm is already installed on the original machine.

A **chart** is a package of templates and default settings. A **release** is a
named installation of a chart. This example installs release `platform-demo` in
namespace `cloud-platform-helm`, alongside the earlier plain-YAML deployment.
There is no migration or shared ownership between them.

## Read the files

- `Chart.yaml`: chart metadata. `version` versions this package; `appVersion`
  describes the app and does not select its container image.
- `values.yaml`: settings for replicas, image, Service port, logging, resources,
  and the deliberately fake demonstration token.
- `templates/deployment.yaml`: creates the Pods with the existing health probes,
  resource settings, and non-root user.
- `templates/service.yaml`: directs traffic to this release's Pods.
- `templates/configmap.yaml`: passes the selected log level to Uvicorn.
- `templates/secret.yaml`: mounts the fake token for learning. The app does not
  use it for authentication. Never put real credentials in these values or Git.
- `values.schema.json`: catches invalid common settings before installation.

For example, `replicas: {{ .Values.replicaCount }}` becomes `replicas: 1` using
the defaults. `.Release.Name` supplies resource names and selector labels;
`.Release.Namespace` supplies their namespace. Another release can use the same
chart without selecting this release's Pods.

The `checksum/config` and `checksum/secret` annotations hash rendered configuration.
Changing either changes the Deployment's Pod template, triggering replacement
Pods automatically so environment variables are refreshed.

## Inspect before installing

```bash
helm lint helm/cloud-platform
helm template platform-demo helm/cloud-platform --namespace cloud-platform-helm
```

`lint` checks chart structure and values. `template` prints the generated YAML
without deploying it. You should recognize the objects from the Kubernetes phase.
Rendered output includes the fake Secret, so treat real-world rendering carefully.

## Install or update

```bash
helm --kubeconfig .local/kubeconfig upgrade --install platform-demo helm/cloud-platform --namespace cloud-platform-helm --create-namespace --wait --timeout 120s
```

`--install` creates the release if missing; otherwise `upgrade` updates it.
`--create-namespace` creates its namespace if needed. `--wait` waits for resources
to become ready. A failed upgrade is not automatically rolled back by this command;
inspect the error and use release history to choose a rollback if necessary.

The explicit kubeconfig targets only this project's local cluster. Do not apply
the old `k8s/` files over these Helm-managed resources.

```bash
helm --kubeconfig .local/kubeconfig status platform-demo -n cloud-platform-helm
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-helm get pods,services
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-helm port-forward service/platform-demo 8003:80 --address 127.0.0.1
```

Keep forwarding running and visit <http://127.0.0.1:8003/> or `/health`, `/metrics`,
and `/docs`. Ctrl+C stops the tunnel without uninstalling the app. If an existing
tunnel already occupies port 8003, use it or choose another local port.

## Practice an upgrade

```bash
helm --kubeconfig .local/kubeconfig upgrade platform-demo helm/cloud-platform -n cloud-platform-helm --set logLevel=debug --wait --timeout 120s
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-helm exec deployment/platform-demo -- printenv UVICORN_LOG_LEVEL
helm --kubeconfig .local/kubeconfig history platform-demo -n cloud-platform-helm
```

`--set` overrides one default for this operation. Expect `debug` from `printenv`.
The checksum annotation rolls out a new Pod automatically. Restart your tunnel
if its selected Pod was replaced. For lasting configuration, edit `values.yaml`
or use a separate values file with `-f`, and supply it consistently on upgrades.

## Practice rollback

Choose a previous successful revision from `history`, for example revision 1:

```bash
helm --kubeconfig .local/kubeconfig rollback platform-demo 1 -n cloud-platform-helm --wait --timeout 120s
```

Rollback restores that revision's configuration and creates a new revision in
history. It does not undo edits to files on disk. Run `printenv` again to verify
the restored log level. This repository was verified by upgrading to `debug`
and rolling back to the initial `info` configuration.

You can also override `replicaCount=2` to explore scaling, but each process has
its own counter: this app does not aggregate metrics across Pods. Defaults stay
at one replica. Keep the image tag in sync with an image loaded into kind.

## Remove only the Helm release when finished

```bash
helm --kubeconfig .local/kubeconfig uninstall platform-demo -n cloud-platform-helm
```

This removes this release's resources. The namespace and earlier `cloud-platform`
deployment remain. Deleting the whole kind cluster also removes both examples.

Interview explanation: "I converted Kubernetes manifests into a Helm chart,
separated settings into values, and used release names in selectors to isolate
installations. I verified installation, configuration upgrade, and rollback."

Reference: [Helm charts documentation](https://helm.sh/docs/topics/charts/).
