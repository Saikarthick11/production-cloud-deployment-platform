"""Create a random Grafana admin password in Kubernetes; never print it."""

import json
import secrets
import subprocess

kubectl = ["kubectl", "--kubeconfig", ".local/kubeconfig", "-n", "monitoring"]
existing = subprocess.run(
    kubectl + ["get", "secret", "grafana-admin", "--ignore-not-found", "-o", "name"],
    capture_output=True,
    text=True,
    check=True,
)
if existing.stdout.strip():
    print("Keeping the existing Grafana admin Secret.")
else:
    secret = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": "grafana-admin", "namespace": "monitoring"},
        "type": "Opaque",
        "stringData": {"admin-user": "admin", "admin-password": secrets.token_urlsafe(24)},
    }
    subprocess.run(kubectl + ["create", "-f", "-"], input=json.dumps(secret), text=True, check=True)
