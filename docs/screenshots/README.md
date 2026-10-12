# GCP deployment screenshots

These original screenshots were captured during the October 12, 2026 cloud test.
The practice environment was subsequently deleted.

- `gke-cluster.png`: healthy `cloud-platform` cluster in `us-central1-a`, showing
  one node, two vCPUs, and 8 GB memory.
- `gke-workload.png`: `cloud-platform-gcp` Deployment with status OK and 1/1 pods.

The console's displayed cost estimate is not proof that the deployment was free.
See the [verification and cleanup record](../../gcp/RESULTS.md) for test outcomes
and the [architecture](../architecture.md) for how this cloud exercise differs
from the automated local deployment.
