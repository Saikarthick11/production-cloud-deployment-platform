# Monitoring: Prometheus and Grafana

This phase is installed locally and is not managed by Argo. The application
remains managed by Argo; monitoring discovers its Pods without changing the app
chart or pushing anything to GitHub.

Prometheus scrapes measurements every 15 seconds and stores time series. Grafana
queries Prometheus and displays charts. The Prometheus Operator configures
scraping from Kubernetes objects such as our `PodMonitor`.

## Files

- `values.yaml`: small local settings for kube-prometheus-stack, including
  Prometheus, Grafana, kube-state-metrics, and node exporter.
- `app-podmonitor.yaml`: selects the GitOps app's Pods and scrapes `/metrics`.
  Its `release: monitoring` label makes this Prometheus installation select it.
- `dashboard.json`: the provisioned **Cloud Platform - Service Overview** dashboard.
- `create_admin_secret.py`: creates a random password only if one does not exist.
  It sends the password directly to Kubernetes, never to Git or terminal output.
- `verify.py`: evaluates all seven dashboard queries against the local Prometheus
  connection and reports any missing samples.

## Recreate the local installation

Run from the project root with Docker Desktop, kind, kubectl, and Helm available.
The chart version is pinned to 92.2.0. Helm installs cluster-scoped monitoring CRDs
and permissions as well as namespace resources.

```bash
mkdir -p .local
curl -fL https://github.com/prometheus-community/helm-charts/releases/download/kube-prometheus-stack-92.2.0/kube-prometheus-stack-92.2.0.tgz -o .local/kube-prometheus-stack-92.2.0.tgz
kubectl --kubeconfig .local/kubeconfig create namespace monitoring --dry-run=client -o yaml | kubectl --kubeconfig .local/kubeconfig apply -f -
python3 monitoring/create_admin_secret.py
helm --kubeconfig .local/kubeconfig upgrade --install monitoring .local/kube-prometheus-stack-92.2.0.tgz -n monitoring -f monitoring/values.yaml --wait --timeout 8m
kubectl --kubeconfig .local/kubeconfig apply -f monitoring/app-podmonitor.yaml
kubectl --kubeconfig .local/kubeconfig -n monitoring create configmap cloud-platform-dashboard --from-file=cloud-platform.json=monitoring/dashboard.json --dry-run=client -o yaml | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl --kubeconfig .local/kubeconfig apply -f -
```

Wait for Helm to finish before applying the PodMonitor: its custom resource type
must be installed first. The dashboard label tells Grafana's sidecar to load it.
Repeat the final command after editing `dashboard.json` to update the local dashboard.
Changes made in Grafana's UI are not automatically saved back to this file.

## Open the interfaces

Use separate terminals and keep each forwarding command running:

```bash
kubectl --kubeconfig .local/kubeconfig -n monitoring port-forward service/monitoring-grafana 3000:80 --address 127.0.0.1
kubectl --kubeconfig .local/kubeconfig -n monitoring port-forward service/monitoring-kube-prometheus-prometheus 9090:9090 --address 127.0.0.1
```

Grafana: <http://127.0.0.1:3000/d/cloud-platform-overview>

Prometheus: <http://127.0.0.1:9090>

Grafana username: `admin`. Retrieve the generated password in your terminal:

```bash
kubectl --kubeconfig .local/kubeconfig -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 --decode
```

Keep the password private. Prometheus has no login in this local setup; its port
is bound only to localhost. Do not expose these services publicly as configured.

## Read the dashboard

| Panel | Meaning |
| --- | --- |
| App scrape health | 1 means app metrics were scraped successfully; 0 means failure |
| Root requests in last 5 minutes | Estimated GET `/` requests, accounting for counter resets |
| Root requests per second | Rate of GET `/` calls, not all API requests |
| App CPU by Pod | CPU cores consumed by each API container |
| App memory by Pod | Working-set memory for each API container |
| Container restarts | Restarts within existing Pods; Pod replacements are different |
| Ready app replicas | Available replicas reported by Kubernetes |

No data is different from zero. Rate panels need multiple scrapes; wait at least
two minutes after installation for CPU/rate queries to have history. The request
counter resets on restart, while Prometheus keeps historical samples. `increase`
uses extrapolation, so short-window request estimates can be fractional.

Kubelet/cAdvisor provides CPU and memory measurements. kube-state-metrics provides
replica and restart state. Built-in Grafana dashboards also show namespace and
cluster resources. In kind, node metrics describe the Linux Docker node, not
your physical Mac directly.

## Generate a small amount of traffic

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-gitops exec deployment/cloud-platform-gitops -- python -c 'import time, urllib.request; [(urllib.request.urlopen("http://cloud-platform-gitops/").close(), time.sleep(0.5)) for _ in range(40)]'
```

This generates 40 root requests over about 20 seconds. Watch the request panels
change. It is a demonstration, not a load test or performance benchmark. Prometheus
scrapes `/metrics`, which does not itself increment the root request counter.

With Prometheus forwarding active and at least a minute of scrape history:

```bash
python3 monitoring/verify.py
```

This checks that each dashboard query has real samples; zero is a valid result
for traffic or restarts. It does not replace checking the app scrape-health value.

## Storage and scope

Prometheus requests 2 GiB of persistent storage, retaining at most two days or
approximately 1 GB of metric blocks. Grafana requests 1 GiB for its database.
These PVCs survive Pod restarts, but deleting the kind cluster deletes local
storage. This is not a backed-up or highly available monitoring installation.

Alertmanager and default alert rules are disabled for this lesson; no external
notifications are configured. Control-plane endpoints that kind does not expose
conveniently are disabled. Operator admission webhooks are disabled to keep this
local installation small. The app does not yet expose latency or HTTP error-rate
metrics, so the dashboard does not claim to show them.

## Troubleshooting and cleanup

```bash
kubectl --kubeconfig .local/kubeconfig -n monitoring get pods,pvc,podmonitors
```

In Prometheus, open **Status → Target health** and find the app target. If absent,
check Pod labels, namespace selection, the PodMonitor release label, and the named
port `http`. If CPU charts are empty, inspect kubelet scrape health. Check pending
Pod events for image-download or memory issues. Empty requests charts can also
mean there have not yet been enough scrapes.

To remove monitoring later:

```bash
helm --kubeconfig .local/kubeconfig uninstall monitoring -n monitoring
kubectl --kubeconfig .local/kubeconfig -n monitoring delete podmonitor/cloud-platform configmap/cloud-platform-dashboard
```

The admin Secret, some PVCs, and operator CRDs can remain after uninstall. Inspect
them before deletion. Never delete shared CRDs while other monitoring installations
use them. Deleting namespace `monitoring` removes its remaining credentials and
storage; deleting the kind cluster removes all local project phases.

Reference: [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).
