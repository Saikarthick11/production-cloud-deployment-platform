# Monitoring: see how the app is doing

[Back to the project](../README.md)

Prometheus collects measurements from the app and Kubernetes. Grafana turns those measurements into charts so we can see traffic, resource use, and restarts.

## Before you start

The local cluster and monitoring installation must be running. The walkthrough includes the first-time setup.

Run all commands from the main project folder.

## How we use it

The dashboard shows requests, CPU and memory use, restarts, and available pods.
It does not currently show request latency or an HTTP error rate.

To open Grafana after setup:

```bash
kubectl --kubeconfig .local/kubeconfig -n monitoring port-forward service/monitoring-grafana 3000:80 --address 127.0.0.1
```

Leave that terminal running and open [Grafana](http://127.0.0.1:3000).
The username is `admin`. In another terminal, retrieve your local password:

```bash
kubectl --kubeconfig .local/kubeconfig -n monitoring get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 --decode
```

Keep the password private. Open **Cloud Platform - Service Overview** to see the
app dashboard. Ctrl+C closes the browser connection, but monitoring keeps running.
Monitoring was installed with Helm; Argo CD manages the app, not this stack.

## Step-by-step instructions

[Open the full walkthrough](walkthrough.md) for setup commands, file explanations,
troubleshooting, and cleanup. You only need this when working on this part of the project.
