# Terraform: plan the GCP setup

[Back to the project](../README.md)

Terraform describes cloud resources in files. This folder is our plan for moving the platform to Google Cloud later. It has passed local checks, but it has not created anything in GCP.

## Before you start

Terraform. Local validation and mock tests do not need a Google Cloud account; downloading the provider needs internet access.

Run all commands from the main project folder.

## How we use it

The configuration describes:

- A private network for the cluster.
- A GKE cluster with one learning-sized node.
- A dedicated identity and permissions for that node.
- An Artifact Registry repository for future container images.

Our working images are still stored in **GHCR**. Writing this configuration does
not move them or install the app in GKE.

On the original development machine, run these from the project folder:

```bash
.tools/terraform -chdir=terraform init -backend=false -input=false
.tools/terraform -chdir=terraform validate
.tools/terraform -chdir=terraform test
```

On another machine, install Terraform and replace `.tools/terraform` with
`terraform`. The tests use fake provider responses, so they do not prove a real
GCP project has the required permissions or quota.

For now, stop at checking and planning. Creating the environment later requires
a real project, credentials, and billing; running it will cost money.

## Step-by-step instructions

[Open the full walkthrough](walkthrough.md) for setup commands, file explanations,
troubleshooting, and cleanup. You only need this when working on this part of the project.
