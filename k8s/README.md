# Kubernetes: keep the app running

[Back to the project](../README.md)

Kubernetes runs the app in a pod and replaces that pod if it disappears. Here, the whole cluster runs locally inside Docker using a tool called kind.

## Before you start

Docker Desktop, kubectl, and kind. Run commands from the main project folder.

Run all commands from the main project folder.

## How we use it

The basic pieces are:

- **Deployment:** asks Kubernetes to keep the app running.
- **Service:** gives the app a stable address inside the cluster.
- **ConfigMap:** holds settings such as the log level.
- **Secret example:** demonstrates a mounted file using a fake token.

This was our first Kubernetes lesson. The Helm and Argo CD examples use separate
namespaces, so you can learn each approach without replacing the earlier one.

If you already installed this example, open it with:

```bash
kubectl --kubeconfig .local/kubeconfig -n cloud-platform get pods
```

For installation, browser access, and cleanup, use the walkthrough below.

## Step-by-step instructions

[Open the full walkthrough](walkthrough.md) for setup commands, file explanations,
troubleshooting, and cleanup. You only need this when working on this part of the project.
