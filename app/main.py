"""A small HTTP service with health and Prometheus metrics endpoints."""

from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Counter, generate_latest

app = FastAPI(title="Production Cloud Deployment Platform", version="0.1.0")

# Keep this app's metrics separate from the library's default global registry.
registry = CollectorRegistry()
root_requests = Counter(
    "platform_root_requests_total",
    "Number of GET requests handled by the root endpoint.",
    registry=registry,
)


@app.get("/")
def read_root() -> dict[str, str]:
    """Identify the service and count visits to this endpoint."""
    root_requests.inc()
    return {"message": "Welcome to the Production Cloud Deployment Platform"}


@app.get("/health")
def health() -> dict[str, str]:
    """Confirm that the app can respond; no external services are checked."""
    return {"status": "healthy"}


@app.get("/metrics", response_class=Response)
def metrics() -> Response:
    """Expose metrics in Prometheus text format instead of JSON."""
    return Response(
        content=generate_latest(registry),
        headers={"Content-Type": CONTENT_TYPE_LATEST},
    )
