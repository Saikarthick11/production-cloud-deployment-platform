# Local verification — October 11, 2026

Environment: project kind cluster `cloud-platform`, Kubernetes v1.34.0,
Metrics Server v0.9.0, Helm release `reliability-demo` in the isolated
`cloud-platform-reliability` namespace.

- CPU autoscaling increased the app from 1 to 3 ready pods under HTTP traffic.
  HPA events reported `SuccessfulRescale` due to CPU utilization above target.
- After traffic stopped, HPA returned from 3 pods to 1. Its event reported
  `New size: 1; reason: All metrics below target`.
- The bounded three-minute load Job completed with **156,642 successful requests
  and 0 reported failed requests**. This is a local exercise, not a production
  benchmark or an availability guarantee.
- Deleting one app pod created a replacement with a new identity; the Deployment
  returned to ready. This exercise occurred while the app had three replicas.
- A deliberately nonexistent image tag caused `ImagePullBackOff`. The rollout
  timed out as expected, and three old app pods remained ready.
- Helm rollback from revision 2 to the known-good revision 1 created revision 3.
  The restored Deployment completed its rollout and the Service `/health`
  endpoint returned `{"status":"healthy"}`.
- The existing Argo CD application remained `Synced` and `Healthy` during testing.
- All 9 existing pytest tests, Ruff checks, Helm lint, and chart ownership/input
  checks passed. Pytest still emits the existing TestClient/httpx deprecation
  warning.

The healthy practice release and Metrics Server remain installed for learning.
The traffic Job finishes on its own. Cleanup commands are in the lesson README.
GitOps adoption of HPA is documented but deferred until a reviewed GitHub push.
No cloud resources, commits, or pushes were made in this phase.
