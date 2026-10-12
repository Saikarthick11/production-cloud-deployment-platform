# Argo CD: deploy what is in Git

[Back to the project](../README.md)

Argo CD watches the deployment files on GitHub and makes the running app match them. This is what we mean by GitOps: Git records the version and settings we want to run.

## Before you start

Docker Desktop and the local kind cluster. Argo CD must be installed using the walkthrough below.

Run all commands from the main project folder.

## How we use it

Our workflow publishes an image, then updates its tag in `gitops/values-local.yaml`.
Argo CD sees that tag and deploys it. Editing a file only on your laptop does not
trigger Argo; the change needs to reach GitHub.

Check the app:

```bash
kubectl --kubeconfig .local/kubeconfig -n argocd get application cloud-platform-gitops
```

Look for **Synced** and **Healthy**. Synced means the deployment matches Git;
Healthy means its Kubernetes resources look ready.

Argo manages this app itself, so use Git to change it rather than `helm upgrade`.
A manual change in the cluster may be undone by Argo's self-healing.

## Step-by-step instructions

[Open the full walkthrough](walkthrough.md) for setup commands, file explanations,
troubleshooting, and cleanup. You only need this when working on this part of the project.
