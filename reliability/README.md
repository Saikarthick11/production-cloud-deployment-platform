# Reliability practice: scaling, recovery, and rollback

Run these commands from the repository root. Docker Desktop must be running.
Every command uses `.local/kubeconfig` to target this project's kind cluster.
The practice release lives in `cloud-platform-reliability`, separately from Argo
CD's existing application. No GitHub push or cloud deployment is required.

## What each file does

- `values.yaml` enables a CPU HorizontalPodAutoscaler (HPA), with one to three pods.
- `metrics-server/components.yaml` is the unmodified official Metrics Server
  v0.9.0 release manifest. `kustomization.yaml` adds a **local kind only** kubelet
  certificate exception. Do not use that exception for GKE or other cloud clusters.
- `load.py` sends HTTP requests using eight threads for three minutes.
- `load-job.yaml` runs that script inside Kubernetes; it stops after four minutes
  at most and is automatically removed ten minutes after completion.
- `check_chart.py` checks replica ownership, rollout settings, and invalid inputs.

The Helm chart now conditionally creates an HPA and omits Deployment `replicas`
when autoscaling is enabled. This prevents Helm from resetting the HPA's decision.
Its rolling updates allow one extra pod and remove no available pods before a
replacement is ready (`maxSurge: 1`, `maxUnavailable: 0`). This requires spare
capacity and healthy existing pods; it is not a guarantee of zero downtime.

Existing requests (100m CPU, 64Mi memory), limits (500m CPU, 256Mi memory),
readiness and liveness probes remain in use. Readiness controls traffic eligibility;
liveness restarts an unhealthy container. Pod deletion below tests the Deployment
controller's replacement behavior, not the liveness probe.

## 1. Install the practice release

```bash
kubectl --kubeconfig .local/kubeconfig get nodes
kubectl --kubeconfig .local/kubeconfig apply -k reliability/metrics-server
kubectl --kubeconfig .local/kubeconfig -n kube-system rollout status deployment/metrics-server --timeout=120s
helm upgrade --install reliability-demo helm/cloud-platform \
  --kubeconfig .local/kubeconfig \
  --namespace cloud-platform-reliability --create-namespace \
  -f gitops/values-local.yaml -f reliability/values.yaml \
  --wait --timeout 180s
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability get hpa
```

`apply -k` installs the reviewed Metrics Server configuration. Helm uses the known
GHCR image from our GitOps values and then applies the practice scaling settings.
Do not replace an existing Metrics Server installation with this local overlay
in another cluster. Metrics Server supplies CPU samples for HPA; Prometheus
continues serving its separate monitoring role. Initial HPA values may show
`<unknown>` until enough samples have arrived.

## 2. Watch autoscaling

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability create configmap reliability-load \
  --from-file=load.py=reliability/load.py --dry-run=client -o yaml | \
  kubectl --kubeconfig .local/kubeconfig apply -f -
kubectl --kubeconfig .local/kubeconfig apply -f reliability/load-job.yaml
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability get hpa --watch
```

The ConfigMap supplies the Python script; the Job runs it against the Service,
which sends traffic to ready app pods. Press Ctrl+C to stop watching; this does
not stop the Job. In another terminal:

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability top pods
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability get pods
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability logs job/reliability-load
```

The CPU target is 60% of the 100m CPU **request**, about 60m per pod. A value over
100% is possible because the CPU limit is higher than the request. HPA estimates
needed replicas from average usage and clamps the result to the one-to-three
range. This scales pods, not the kind node or your laptop.

The script prints request totals after it finishes. Expect the replica count to
rise under sufficient traffic and return toward one after the load ends. The
60-second downscale stabilization window and metrics delays prevent an immediate
return. Exact timing depends on the laptop and cluster load. If metrics remain
unknown, inspect `kubectl ... describe hpa reliability-demo` and Metrics Server
logs; if pods are Pending, inspect pod events for capacity problems.

To stop early or rerun the load, delete only its Job, then apply it again:

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability delete job reliability-load --ignore-not-found
```

## 3. Verify pod recovery

Wait for the load to finish before this exercise. Record one pod's name, delete
it, and watch Kubernetes create a different pod:

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability get pods -l app.kubernetes.io/instance=reliability-demo
PRACTICE_POD=$(kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability get pods -l app.kubernetes.io/instance=reliability-demo -o jsonpath='{.items[0].metadata.name}')
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability delete pod "$PRACTICE_POD"
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability rollout status deployment/reliability-demo --timeout=120s
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability get pods -l app.kubernetes.io/instance=reliability-demo
```

The Deployment's ReplicaSet restores the desired number of pods. A one-pod
service can be briefly unavailable during replacement. Multiple pods on one
node still do not protect against node failure.

## 4. Simulate a failed rollout and recover

This deliberately changes only the practice release to an image tag that does
not exist. First note the known-good Helm revision:

```bash
helm history reliability-demo --kubeconfig .local/kubeconfig -n cloud-platform-reliability
helm upgrade reliability-demo helm/cloud-platform \
  --kubeconfig .local/kubeconfig -n cloud-platform-reliability \
  -f gitops/values-local.yaml -f reliability/values.yaml \
  --set-string image.tag=deliberately-missing-reliability-demo
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability get pods
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability rollout status deployment/reliability-demo --timeout=45s
```

The last command is expected to time out. Inspect the new pod's events with
`describe pod`: it should report an image pull failure. Existing ready pods should
remain because `maxUnavailable` is zero. Kubernetes reports a stalled rollout;
it does **not** automatically roll back the Deployment.

Roll back to the known-good revision from the history output. For a fresh
installation the good revision is 1; replace `1` if you have upgraded before:

```bash
helm rollback reliability-demo 1 --kubeconfig .local/kubeconfig \
  -n cloud-platform-reliability --wait --timeout 120s
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability rollout status deployment/reliability-demo --timeout=120s
helm history reliability-demo --kubeconfig .local/kubeconfig -n cloud-platform-reliability
```

This uses Helm rollback because the practice release is managed by Helm. For
our Argo CD application, the lasting recovery is to restore the known-good image
in Git and let Argo sync it. A manual live change can be undone by self-healing.
We are postponing that Git-based exercise until pushing is authorized.

## GitOps adoption later

Autoscaling is disabled by default and is not yet enabled in `gitops/values-local.yaml`.
Before enabling it there, allow `autoscaling/HorizontalPodAutoscaler` in the
AppProject, then configure the Application to ignore `/spec/replicas` for its
Deployment and enable `RespectIgnoreDifferences=true`. Apply those controller
settings together with the HPA-enabled chart after review. When returning to
fixed replica counts, remove that ignore rule. The current GitOps setup retains
its original replica self-healing behavior.

## Checks and cleanup

```bash
python3 reliability/check_chart.py
helm lint helm/cloud-platform
helm uninstall reliability-demo --kubeconfig .local/kubeconfig -n cloud-platform-reliability
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability delete job reliability-load --ignore-not-found
kubectl --kubeconfig .local/kubeconfig -n cloud-platform-reliability delete configmap reliability-load --ignore-not-found
```

Cleanup stops the practice app and its traffic. Metrics Server remains available
for future local HPA exercises. The separate Argo application and monitoring stack
are not part of this cleanup.

References: [Kubernetes HPA](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/),
[Metrics Server](https://github.com/kubernetes-sigs/metrics-server/tree/v0.9.0),
[Argo sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#respect-ignore-difference-configs).
