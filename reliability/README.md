# Reliability: try a failure and recover

[Back to the project](../README.md)

This lesson checks what happens when the app gets busy, a pod disappears, or a new image cannot start. We use a separate practice app so the main GitOps app can keep running.

## Before you start

Docker Desktop, the local cluster, and Helm. The walkthrough installs Metrics Server for CPU autoscaling.

Run all commands from the main project folder.

## How we use it

We tested three things:

1. **Scaling:** traffic grew the app from one pod to three; it returned to one afterward.
2. **Recovery:** deleting a pod caused Kubernetes to create a replacement.
3. **Rollback:** a bad image failed to start, and Helm restored the earlier working version.

The chart keeps old ready pods during a rolling update. Kubernetes does not
roll back a failed deployment automatically; we performed that recovery step.

[See the recorded test results](RESULTS.md).

The practice app lives in `cloud-platform-reliability`. Autoscaling is still
disabled for the main GitOps app. Follow the walkthrough for the exact commands,
what to expect, and how to remove the practice app when finished.

## Step-by-step instructions

[Open the full walkthrough](walkthrough.md) for setup commands, file explanations,
troubleshooting, and cleanup. You only need this when working on this part of the project.
