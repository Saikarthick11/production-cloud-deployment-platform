# Helm: reuse the deployment settings

[Back to the project](../../README.md)

Helm lets us keep one set of Kubernetes templates and supply different settings for each installation. Instead of copying several files, we change values such as the image tag or replica count.

## Before you start

The local Kubernetes cluster and its app image from the Kubernetes lesson. Helm must be installed.

Run all commands from the main project folder.

## How we use it

A **chart** is the package of templates. A **release** is one installation of it.
Our practice release is called `platform-demo`.

Start by reading `values.yaml`. It holds the settings you are most likely to
change. Files in `templates/` turn those settings into Kubernetes resources.
Autoscaling is optional and is covered in the reliability guide.

You can check the chart without installing it:

```bash
helm lint helm/cloud-platform
helm template platform-demo helm/cloud-platform
```

The second command prints the Kubernetes configuration Helm would create.

## Step-by-step instructions

[Open the full walkthrough](walkthrough.md) for setup commands, file explanations,
troubleshooting, and cleanup. You only need this when working on this part of the project.
