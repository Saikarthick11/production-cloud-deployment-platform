# Terraform: describe the GCP environment

[Back to the short guide](README.md)

This guide begins with checks that do not create resources. The configuration
was later used for a real GCP test and then torn down; see the
[cloud results](../gcp/RESULTS.md). Images still come from GHCR. The local kind
cluster and GitHub workflow are separate from this configuration.

Terraform compares a desired configuration with recorded infrastructure state.
`plan` previews changes; `apply` makes them. Start with validation
and mocked plans. A real GCP plan needs your project and credentials.

## What the configuration describes

- A custom VPC and subnet, with separate IP ranges for nodes, pods, and services.
- Private Google API access and Cloud NAT so private nodes can pull GHCR images.
- A dedicated node service account with Google's minimum GKE node role.
- A Docker Artifact Registry repository and repository-scoped node read access.
- A zonal GKE Standard cluster with one `e2-standard-2` node, Workload Identity,
  health repair, automatic upgrades, Shielded nodes, and deletion protection.
- A public Kubernetes API endpoint restricted to your IPv4 address (`/32`).

A private **node** does not mean a private **API endpoint**. This setup allows your
laptop to reach the API from its allowed public address while nodes have no
public IPs. If your address changes, update `admin_cidr` before a future plan.
Cloud NAT provides outbound access, not inbound access to the application.

This is a learning environment, not a highly available production deployment.
It has one node in one zone, no public app ingress, no application installation,
and no remote Terraform state backend. A future deployment incurs charges for
GKE, compute, disks, NAT, registry storage, and related usage. No resources or
billing budgets are created by the checks below.

## Files and why they exist

| File | Purpose |
| --- | --- |
| `versions.tf` | Specifies Terraform compatibility, pins Google provider 8.6.0, and selects project/location. |
| `.terraform.lock.hcl` | Records the provider version and checksums for repeatable installation; keep in Git. |
| `variables.tf` | Inputs and validation, including a single allowed admin IP. |
| `network.tf` | Required APIs, VPC, subnet, router, and outbound NAT. |
| `iam.tf` | Node identity and permissions; creates no service-account keys. |
| `registry.tf` | Future Docker image repository in Artifact Registry. |
| `gke.tf` | Cluster and a separately managed node pool. |
| `outputs.tf` | Useful names and the future registry path. |
| `terraform.tfvars.example` | Safe example inputs to copy before a real plan. |
| `tests/platform.tftest.hcl` | Mocked plan checks and invalid-input tests. |

Terraform reads all `.tf` files in this directory as one configuration. Their
names organize the lesson; filename order does not control creation order.
References and `depends_on` determine dependencies. We use one root module here
to keep the resource relationships visible before introducing reusable modules.

## Run local checks (no GCP account needed)

Open a terminal at the repository root, the folder containing `app`, `helm`, and
`terraform`. This Mac workspace has Terraform 1.16.5 installed at
`.tools/terraform`; it was downloaded from HashiCorp and checksum-verified.
The local executable is ignored by Git. On another machine, install Terraform
from the [official installation guide](https://developer.hashicorp.com/terraform/install)
and replace `.tools/terraform` below with `terraform`.

```bash
.tools/terraform version
.tools/terraform fmt -check -recursive terraform
.tools/terraform -chdir=terraform init -backend=false -input=false
.tools/terraform -chdir=terraform validate
.tools/terraform -chdir=terraform test
```

1. `version` identifies the installed tool.
2. `fmt -check` checks formatting without editing files. Omit `-check` to format.
3. `init` downloads the pinned provider and checks its lock file. It needs internet
   access but no Google login. `-backend=false` skips backend initialization.
4. `validate` checks syntax and resource fields against the provider schema.
5. `test` runs three **mocked plans**, including rejection of unrestricted API
   access and a zone outside the selected region. The mock provider does not
   contact Google Cloud or create resources.

Passing these checks does not prove a real project has sufficient permissions,
quota, billing, or compatible organization policies. Mock values cannot test
GCP's server-side validation or actual network connectivity.

## Later: preview against a real project

This is a separate future step. You need an existing GCP project with billing,
the [Google Cloud CLI](https://cloud.google.com/sdk/docs/install), and an identity
allowed to inspect/manage the declared APIs, network, IAM, registry, and GKE
resources. An administrator may need to enable Service Usage and Cloud Resource
Manager first so Terraform can manage project services. Organization policies
can impose additional restrictions. No credentials belong in this repository.

From the repository root:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit the copied file: enter your real project ID and replace the documentation
IP with your current public IPv4 address followed by `/32`. Keep the zone within
the selected region. The copied file is ignored by Git.

```bash
gcloud auth application-default login
.tools/terraform -chdir=terraform init -input=false
.tools/terraform -chdir=terraform plan -out=preview.tfplan
.tools/terraform -chdir=terraform show preview.tfplan
```

The login sets up local Application Default Credentials for Terraform. `init`
prepares the default local state backend. `plan` reads cloud information and
saves a proposed change set; `show` lets you inspect it again. A real plan may
fail because of project setup, quota, or permissions; fix those before any
future deployment. **Stop here for this phase.** No apply is part of this lesson.

State and saved plans can contain sensitive infrastructure data. Git ignores
both, along with provider downloads and real input files. Do not attach them to
GitHub issues. Before team use, configure a restricted remote backend with
locking instead of relying on one laptop's local state.

## Important behavior for a future deployment

- GHCR remains the active image registry. Terraform only creates an empty
  Artifact Registry repository if applied later. Publishing images there and
  changing the Helm image reference are separate work.
- Terraform does not install Argo CD, Prometheus, Grafana, or our app into GKE.
- Workload Identity enables separate pod identities; no app-specific Google
  permissions are granted here. OAuth scopes allow Google APIs, while IAM roles
  determine what the node identity may actually do.
- GKE initially creates a temporary default node pool, which Terraform removes
  in favor of our managed pool. It also uses the dedicated node identity.
- Deletion protection prevents accidental cluster deletion. Future cleanup
  requires explicitly changing that setting and applying it before destruction.
  Review the full destroy plan; project APIs intentionally stay enabled.
- The single node is for learning. Check capacity before installing the full
  monitoring stack; scaling and availability are later exercises.

## Interview explanation

“I wrote Terraform configuration for a GCP deployment of my platform: networking,
a private-node GKE cluster, node permissions, and an Artifact Registry repository.
I validated the configuration and used mocked plans to test important settings.
I also provisioned a GKE practice environment, deployed the app with Helm,
verified its endpoints, and removed the resources after testing. My GitOps and
monitoring setup runs locally; both deployments used images from GHCR.”

## References

- [Terraform test mocks](https://developer.hashicorp.com/terraform/language/tests/mocking)
- [Google provider cluster resource](https://registry.terraform.io/providers/hashicorp/google/8.6.0/docs/resources/container_cluster)
- [GKE node service accounts](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/service-accounts)
