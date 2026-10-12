"""Check Helm's scaling ownership and reject invalid HPA settings."""

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def render(*args, succeeds=True):
    result = subprocess.run(
        ["helm", "template", "reliability-demo", "helm/cloud-platform", *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    assert (result.returncode == 0) == succeeds, result.stderr
    return result.stdout


if __name__ == "__main__":
    fixed = render()
    scaled = render("--set", "autoscaling.enabled=true")
    assert "kind: HorizontalPodAutoscaler" not in fixed
    assert "  replicas: 1" in fixed
    assert "kind: HorizontalPodAutoscaler" in scaled
    assert "  replicas:" not in scaled, "HPA must own the replica count"
    assert "maxUnavailable: 0" in scaled and "maxSurge: 1" in scaled
    render("--set", "autoscaling.enabled=true,autoscaling.minReplicas=4", succeeds=False)
    render("--set", "autoscaling.targetCPUUtilizationPercentage=0", succeeds=False)
    render("--set", "autoscaling.enabled=true,resources.requests.cpu=", succeeds=False)
    print("Chart checks passed: fixed replicas, HPA ownership, rolling updates, invalid inputs.")
