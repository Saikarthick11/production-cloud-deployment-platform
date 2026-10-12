# Try the app on Google Cloud

[Back to the project](../README.md)

**Status:** tested successfully and deleted on October 12, 2026. The commands
below are for recreating the exercise; the cloud app links are no longer live.
See [verification and cleanup results](RESULTS.md).

This is a short-lived GKE practice deployment. The cloud app uses the same Helm
chart and GHCR image as our local project. For this first cloud exercise, Helm
installs the app directly; Argo CD and the Grafana stack still run locally.

## Connect from the original development machine

Run commands from the main project folder. These settings keep the cloud login
and Kubernetes connection separate from your other projects:

```bash
export CLOUDSDK_CONFIG="$PWD/.local/gcloud"
export PATH="$PWD/.tools/google-cloud-sdk/bin:$PATH"
export KUBECONFIG="$PWD/.local/gke-kubeconfig"
export GOOGLE_APPLICATION_CREDENTIALS="$PWD/.local/gcloud/application_default_credentials.json"
```

The project ID and allowed administrator IP are in the ignored
`terraform/terraform.tfvars` file. Credentials, cluster connection files,
Terraform state, and saved plans must stay out of Git.

After the cluster exists, connect to it:

```bash
gcloud container clusters get-credentials cloud-platform \
  --zone us-central1-a --project project-6d21a5ea-166b-4432-9a0
kubectl --kubeconfig .local/gke-kubeconfig get nodes
```

The Kubernetes API allows only the administrator IP from the Terraform settings.
If your network changes, update that address and review a fresh Terraform plan.
Do not open API access to the whole internet to fix a connection problem.

## Install or update the app

```bash
helm upgrade --install cloud-platform-gcp helm/cloud-platform \
  --kubeconfig .local/gke-kubeconfig \
  --namespace cloud-platform-gcp --create-namespace \
  -f gitops/values-local.yaml --wait --timeout 180s
kubectl --kubeconfig .local/gke-kubeconfig -n cloud-platform-gcp get pods,services
```

This downloads the existing scanned image from GHCR. Artifact Registry is created
as part of the Terraform exercise but is not yet used to store our images.
The app has one replica; autoscaling is disabled for this first cloud test.

## Open the cloud app on your laptop

```bash
kubectl --kubeconfig .local/gke-kubeconfig -n cloud-platform-gcp \
  port-forward service/cloud-platform-gcp 8005:80 --address 127.0.0.1
```

Leave that terminal running, then visit:

- [App](http://127.0.0.1:8005/)
- [Health check](http://127.0.0.1:8005/health)
- [Metrics](http://127.0.0.1:8005/metrics)
- [API docs](http://127.0.0.1:8005/docs)

Although the browser address is local, the app process runs on GKE. The command
opens an authenticated tunnel to it. There is no public website or load balancer.
Stopping the tunnel does not stop the cloud resources or their charges.

## Delete the practice environment when finished

Use the same terminal environment settings shown above. Keep the Terraform
state files: Terraform needs them to track and delete what it created.

The cluster has deletion protection. First change `deletion_protection` to
`false` in your ignored `terraform/terraform.tfvars` file. Then:

```bash
.tools/terraform -chdir=terraform plan -out=allow-cleanup.tfplan
.tools/terraform -chdir=terraform show allow-cleanup.tfplan
```

Check that the plan only disables cluster deletion protection. Apply that
reviewed plan, then preview deletion:

```bash
.tools/terraform -chdir=terraform apply allow-cleanup.tfplan
.tools/terraform -chdir=terraform plan -destroy -out=cleanup.tfplan
.tools/terraform -chdir=terraform show cleanup.tfplan
```

The destroy plan should remove this practice cluster, node pool, network, NAT,
registry, and node identity/permissions. It should not touch unrelated resources.
Once reviewed, run:

```bash
.tools/terraform -chdir=terraform apply cleanup.tfplan
.tools/terraform -chdir=terraform state list
```

The state list should be empty. Also check the GCP console for any remaining
project-related VMs, disks, IP addresses, routers, and Artifact Registry storage.
Enabled APIs stay enabled but do not by themselves run the app. If you create
extra resources outside Terraform during practice, remove those separately.

Set `deletion_protection` back to `true` in your local settings before a future
creation. Billing reports can take time to catch up after deletion.
