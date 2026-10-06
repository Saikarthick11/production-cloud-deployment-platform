# Kubernetes: run the app in a local cluster

Run these commands from the repository root, not from this `k8s` folder.
Docker Desktop must be running. This phase uses kind (Kubernetes in Docker) and
kubectl (the Kubernetes client). There are no cloud resources or cloud charges.

Verified locally: kind v0.33.0, Kubernetes v1.34.0, and kubectl v1.34.1; one ready
Pod; HTTP responses through the Service; ConfigMap environment variable; fake
Secret file; non-root user; and automatic Pod replacement after deletion. The
existing six Python tests also pass. The node version matches the installed
kubectl minor version for this learning setup.

## Files and concepts

| File | Purpose |
| --- | --- |
| `kind.yaml` | Creates a single-node local learning cluster |
| `namespace.yaml` | Groups this project's Kubernetes objects |
| `deployment.yaml` | Keeps one app Pod running and defines its container settings |
| `service.yaml` | Gives matching Pods a stable internal address on port 80 |
| `configmap.yaml` | Supplies the non-secret `UVICORN_LOG_LEVEL=info` setting |
| `secret.example.yaml` | Supplies a deliberately fake token as a mounted file |

A Pod wraps the running container. A Deployment manages replacement Pods if one
disappears. A Service selects Pods by label (`app: cloud-platform`), forwarding
its port 80 to their named `http` port, 8000.

Readiness probes ask whether a Pod should receive Service traffic. Liveness probes
ask whether its container needs restarting after repeated failures. Both use
`/health` here because this app has no external dependencies. Neither proves that
an external database or cloud service works.

The CPU request is 100m (0.1 CPU) and limit is 500m (0.5 CPU). Memory is requested
at 64Mi and limited to 256Mi. These are learning defaults, not measured production
capacity requirements. The container runs with user ID 10001, matching Docker.

## 1. Tools

On the original Mac, `.tools/kind` is installed locally for this project. On a new
Apple Silicon Mac, download it with:

```bash
mkdir -p .tools .local
curl -fL https://kind.sigs.k8s.io/dl/v0.33.0/kind-darwin-arm64 -o .tools/kind
chmod +x .tools/kind
.tools/kind version
kubectl version --client
```

For Intel Macs use `kind-darwin-amd64`; for other systems follow the official
[kind installation guide](https://kind.sigs.k8s.io/docs/user/quick-start/).
If kubectl is missing, use its [installation instructions](https://kubernetes.io/docs/tasks/tools/).
`chmod +x` makes the downloaded program executable.

`.tools/` and `.local/` are ignored by Git. The latter holds cluster access
credentials: do not commit or share it.

## 2. Create the cluster once

```bash
mkdir -p .local
.tools/kind create cluster --name cloud-platform --image kindest/node:v1.34.0 --config k8s/kind.yaml --kubeconfig .local/kubeconfig --wait 120s
kubectl --kubeconfig .local/kubeconfig get nodes
```

The explicit kubeconfig keeps these operations separate from your other clusters.
Use it on every kubectl command below. If the cluster already exists, skip creation.
Expect one node with status `Ready`. Cluster creation downloads a Kubernetes node
image and may take several minutes the first time.

## 3. Build and load the app image

```bash
docker build -t cloud-platform:k8s-v1 .
.tools/kind load docker-image cloud-platform:k8s-v1 --name cloud-platform
```

Docker's image store and the cluster's image store are separate. Loading the image
copies it into kind. The Deployment uses that exact tag with `IfNotPresent`, so
Kubernetes can use the loaded image without a remote registry.

## 4. Apply the manifests

```bash
kubectl --kubeconfig .local/kubeconfig apply -f k8s/namespace.yaml
kubectl --kubeconfig .local/kubeconfig apply -f k8s/configmap.yaml -f k8s/secret.example.yaml -f k8s/deployment.yaml -f k8s/service.yaml
kubectl --kubeconfig .local/kubeconfig -n cloud-platform rollout status deployment/cloud-platform --timeout=120s
kubectl --kubeconfig .local/kubeconfig -n cloud-platform get pods,services
```

`apply` submits the desired state; repeating it updates existing objects. Create
the Namespace first because the other objects belong to it. Do not apply the whole
folder: `kind.yaml` is cluster-creation configuration, not a Kubernetes API object.
Expect one Pod showing `1/1` ready and a `ClusterIP` Service.

## 5. Open the app

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform port-forward service/cloud-platform 8002:80 --address 127.0.0.1
```

Keep that terminal running. In another terminal:

```bash
curl --fail http://127.0.0.1:8002/
curl --fail http://127.0.0.1:8002/health
curl --fail http://127.0.0.1:8002/metrics
```

Open <http://127.0.0.1:8002/docs> to explore the API. The forwarding command connects
your laptop's port 8002 to a Pod selected by the Service, using Service port 80.
It is a local debugging tunnel, not a public endpoint or production ingress.
Ports 8000 and 8001 remain available for the earlier Python and Docker examples.
Press Ctrl+C to stop forwarding; the cluster and app keep running.

## 6. Inspect configuration and the fake Secret

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform logs deployment/cloud-platform
kubectl --kubeconfig .local/kubeconfig -n cloud-platform exec deployment/cloud-platform -- printenv UVICORN_LOG_LEVEL
kubectl --kubeconfig .local/kubeconfig -n cloud-platform exec deployment/cloud-platform -- ls -l /var/run/secrets/cloud-platform
```

The ConfigMap becomes an environment variable read by Uvicorn. The fake Secret
becomes `/var/run/secrets/cloud-platform/demo-token`. It demonstrates mounting;
the app does not read it or implement authentication. Never replace the tracked
example with real credentials. Kubernetes Secrets are not automatically encrypted
just because their API values are base64 encoded.

To try configuration changes, edit `info` to `debug` in `configmap.yaml`, then:

```bash
kubectl --kubeconfig .local/kubeconfig apply -f k8s/configmap.yaml
kubectl --kubeconfig .local/kubeconfig -n cloud-platform rollout restart deployment/cloud-platform
kubectl --kubeconfig .local/kubeconfig -n cloud-platform rollout status deployment/cloud-platform
```

Environment variables are captured when a container starts, so existing containers
need replacing to pick up this change. Verify with the `printenv` command again.
Restart port-forward if the Pod it was attached to was replaced.

## 7. Observe automatic replacement

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform get pods
kubectl --kubeconfig .local/kubeconfig -n cloud-platform delete pod -l app=cloud-platform
kubectl --kubeconfig .local/kubeconfig -n cloud-platform get pods --watch
```

This intentionally interrupts this demo's single replica. A new Pod appears
because the Deployment still requests one. Watch until it becomes `1/1`, then
press Ctrl+C. The Pod name changes and its counter starts fresh. Restart the
port-forward command to attach to the replacement. One replica is not highly
available; the exercise illustrates reconciliation, not zero-downtime recovery.

## 8. Deploy later code changes

Use a fresh image tag such as `cloud-platform:k8s-v2`: build it, load it into kind,
update `image:` in `k8s/deployment.yaml`, then apply that file and watch rollout
status again. Rebuilding the same tag alone does not replace running Pods.

## Troubleshooting and cleanup

- `ImagePullBackOff`: check the tag matches, load the image into `cloud-platform`,
  and ensure `imagePullPolicy` is `IfNotPresent`.
- Pod not ready: inspect `kubectl --kubeconfig .local/kubeconfig -n cloud-platform describe pods`
  and the logs command above. Events explain scheduling, image, and probe failures.
- Docker connection failure: start Docker Desktop and check `docker version`.
- Port 8002 occupied: use `8003:80` and open port 8003 instead.
- API connection failure: check Docker and the project kubeconfig. Do not switch
  to an unrelated cluster to make the command succeed.

When finished, this removes only this project's kind cluster and its workloads:

```bash
.tools/kind delete cluster --name cloud-platform --kubeconfig .local/kubeconfig
```

Your source files and Docker app image remain. Recreate the cluster, load the
image, and apply the manifests to start again.

Interview explanation: "I loaded my Docker image into a local kind cluster and
used a Deployment to maintain one replica. A Service selects the Pod by label.
Readiness controls traffic eligibility; liveness can restart an unresponsive
container. I separated configuration with a ConfigMap and practiced Secret
mounting with a fake value. I verified Pod replacement after deletion."

References: [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/),
[Kubernetes probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/).
