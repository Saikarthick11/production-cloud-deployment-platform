"""Test the API's public behavior without starting a network server."""

import pytest
from fastapi.testclient import TestClient
from prometheus_client.parser import text_string_to_metric_families

from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def root_count(client: TestClient) -> float:
    """Read the exported value, without relying on the counter's internals."""
    response = client.get("/metrics")
    for family in text_string_to_metric_families(response.text):
        for sample in family.samples:
            if sample.name == "platform_root_requests_total":
                return sample.value
    raise AssertionError("Root request counter is missing")


def test_root(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Welcome to the Production Cloud Deployment Platform"}


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_metrics_format(client):
    response = client.get("/metrics")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/plain")
    assert "# TYPE platform_root_requests_total counter" in response.text
    assert root_count(client) >= 0


def test_root_requests_increment_counter(client):
    before = root_count(client)
    client.get("/")
    client.get("/")
    assert root_count(client) == before + 2


def test_monitoring_requests_do_not_increment_root_counter(client):
    before = root_count(client)
    client.get("/health")
    client.get("/metrics")
    assert root_count(client) == before


def test_unknown_route(client):
    assert client.get("/does-not-exist").status_code == 404
