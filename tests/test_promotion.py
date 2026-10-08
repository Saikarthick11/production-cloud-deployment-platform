"""Promotion must preserve application settings and reject malformed input."""

import pytest

from scripts.promote_image import promote

VALUES = """image:
  repository: cloud-platform
  tag: gitops-v1
  pullPolicy: IfNotPresent
replicaCount: 2
logLevel: debug
"""


def test_promotion_preserves_configuration():
    result = promote(VALUES, "ghcr.io/Example/app", "sha-" + "a" * 40)
    assert "repository: ghcr.io/example/app" in result
    assert "tag: sha-" + "a" * 40 in result
    assert "replicaCount: 2\nlogLevel: debug" in result


def test_promotion_rejects_non_commit_tag():
    with pytest.raises(ValueError):
        promote(VALUES, "ghcr.io/example/app", "latest")


def test_promotion_rejects_missing_setting():
    with pytest.raises(ValueError):
        promote(VALUES.replace("  tag: gitops-v1\n", ""), "ghcr.io/example/app", "sha-" + "a" * 40)
