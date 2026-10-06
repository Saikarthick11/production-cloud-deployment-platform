# Production Cloud Deployment Platform

A small FastAPI service that you can run, test, and explain locally. This is the
application foundation for a future cloud project, not a production platform yet.
Day 1 builds the API; the following phases package it with Docker and run it in
local Kubernetes. GitHub Actions now tests, scans, and publishes images; deployment
automation and Terraform are later phases.

Already finished Docker? Continue with [the Kubernetes walkthrough](k8s/README.md).

Already finished Kubernetes? Continue with [the Helm walkthrough](helm/cloud-platform/README.md).

Already finished Helm? Continue with [the CI walkthrough](docs/ci.md).

Already ran the app locally? Continue with [the Docker walkthrough](#6-package-and-run-with-docker).

## What you built

| Request | Response | Purpose |
| --- | --- | --- |
| `GET /` | JSON welcome message | Identify the service and count visits |
| `GET /health` | `{"status":"healthy"}` | Confirm that the app can respond |
| `GET /metrics` | Prometheus text | Expose the root request counter |

All three return HTTP status `200` on success. An unknown route returns `404`.

## Files and why they exist

```text
production-cloud-deployment-platform/
├── app/
│   ├── __init__.py
│   └── main.py
├── tests/
│   └── test_main.py
├── .gitignore
├── .dockerignore
├── Dockerfile
├── pytest.ini
├── requirements.txt
├── requirements-dev.txt
└── README.md
```

- `app/__init__.py` marks `app` as a Python package so it can be imported.
- `app/main.py` creates the FastAPI object, counter, and three route functions.
  Keeping them together makes this small app easy to read; extra layers can wait.
- `tests/test_main.py` checks responses and counter behavior using TestClient.
  It calls the app directly, so tests do not need a running server or an open port.
- `requirements.txt` pins the direct runtime dependencies: FastAPI handles routing
  and JSON, Uvicorn serves HTTP requests, and prometheus-client formats metrics.
- `requirements-dev.txt` includes runtime dependencies and adds pytest (test
  runner) and HTTPX (used by TestClient). These pin direct dependencies, not the
  entire dependency tree; they are not a full lockfile.
- `pytest.ini` tells pytest to look in `tests/`.
- `.gitignore` excludes the local environment, caches, editor settings, and `.env`
  files. The app does not require secrets or an `.env` file.
- `README.md` is this setup guide and explanation.
- `Dockerfile` describes how to package Python, runtime dependencies, and the app.
- `.dockerignore` limits what files Docker receives during the build; your local
  `.venv`, Git history, tests, and local settings are excluded.

## 1. Set up locally (macOS or Linux)

Use Python 3.14 for the environment used to verify this project. Check your version:

```bash
python3 --version
```

Clone the repository and enter its folder:

```bash
git clone https://github.com/Saikarthick11/production-cloud-deployment-platform.git
cd production-cloud-deployment-platform
```

If you already have the project locally, open its existing folder instead of cloning
again. Run all remaining commands from the folder containing this README.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
```

What each command does:

1. `python3 -m venv .venv` creates an isolated Python environment in `.venv`.
   This keeps project libraries separate from your other projects.
2. `source .venv/bin/activate` makes this terminal use that environment's Python.
   Repeat activation whenever you open a new terminal for the project.
3. `python -m pip install -r requirements-dev.txt` installs the listed dependencies
   into that same Python environment. Installation needs internet access.

An environment is already present on the original machine after verification;
you can simply activate it. Do not copy `.venv` between machines—recreate it.

## 2. Run the app

```bash
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

`app.main` means the `app/main.py` module. The `:app` part selects the FastAPI
object named `app` inside it. Uvicorn runs the server. `--reload` restarts it when
you edit Python files and is intended for local development. The host binds it
to your own computer; the port is the local address's numbered entry point.

Leave this terminal running. Open these in a browser:

- Home: <http://127.0.0.1:8000/>
- Health: <http://127.0.0.1:8000/health>
- Metrics: <http://127.0.0.1:8000/metrics>
- Interactive API documentation: <http://127.0.0.1:8000/docs>

Or use a second terminal to send HTTP requests:

```bash
curl http://127.0.0.1:8000/
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/metrics
```

`curl` fetches a URL and prints its response. The first two responses are:

```json
{"message":"Welcome to the Production Cloud Deployment Platform"}
```

```json
{"status":"healthy"}
```

The metrics response includes these lines (the number depends on your visits):

```text
# HELP platform_root_requests_total Number of GET requests handled by the root endpoint.
# TYPE platform_root_requests_total counter
platform_root_requests_total 1.0
```

The library may also emit a creation timestamp. Visit `/` again, then refresh
`/metrics`: the counter increases by one. Health checks, documentation requests,
and metrics requests do not increment this particular counter.

Stop the server with **Ctrl+C**. Run `deactivate` when you want to leave the
virtual environment in that terminal.

## 3. Run the tests

From the repository folder, with the environment activated:

```bash
python -m pytest -q
python -m pip check
```

`python -m pytest` discovers and runs functions whose names start with `test_`.
`-q` makes its output shorter. Expect **6 passed**. `pip check` checks installed
dependencies for missing packages and incompatible version requirements.
The server can be stopped: tests run their own in-process app.

With the verified dependency versions, Starlette emits one deprecation warning
about its HTTPX-backed TestClient. All six tests pass; the warning concerns a
future test-client migration, not a failing endpoint.

The six tests cover the welcome response, health response, metrics format,
counter increments, monitoring requests not changing the counter, and an unknown
route returning `404`. The counter tests compare before/after values instead of
assuming zero, because the imported app is shared across tests.

## 4. Understand the code

Read `app/main.py` from top to bottom:

1. Imports bring in FastAPI and the Prometheus building blocks.
2. `FastAPI(...)` creates the application object that Uvicorn serves.
3. `CollectorRegistry()` stores this app's metrics separately from the library's
   default registry. `Counter(...)` creates a numeric metric that increases.
4. `@app.get("/")` connects a GET request at `/` to `read_root()`.
   The function increments the counter and returns a dictionary; FastAPI turns
   that dictionary into JSON. Its type hint documents the keys and values.
5. The health function returns a simple liveness response. It does not check a
   database, cloud resources, or external services.
6. The metrics function serializes the registry and returns a raw `Response`
   with the Prometheus content type, because these bytes are text rather than JSON.

These functions use normal `def` because their work is small and synchronous.
There is no asynchronous database or network call to await here.

The counter lives in memory and resets when the process restarts, including
development reloads. This Day 1 app assumes a single server process; it does not
combine counters across multiple workers or machines. Prometheus can collect
metrics later, but no Prometheus server is needed to view this endpoint now.

## 5. Practice before moving on

1. Change the welcome message, reload the browser, and observe the new response.
2. Run the tests. Explain why the welcome-message test now fails.
3. Update the expected message in the test and rerun it, or undo your change.
4. Visit `/` three times. Confirm that the counter increases by three.
5. Restart the server and explain why the counter returns to zero before a new visit.

An interview explanation you should be able to give in your own words:

> I built a small FastAPI service with a welcome endpoint, a liveness endpoint,
> and a Prometheus metrics endpoint. Uvicorn serves the app. A counter tracks
> requests to the root route, and pytest checks the API through TestClient.
> The health check only proves the app responds, and the metrics are currently
> stored in one process's memory. This is the application foundation for my
> later deployment work.

## 6. Package and run with Docker

An **image** is the packaged application plus its runtime and dependencies.
A **container** is a running instance of that image. The Dockerfile is the recipe
used to build the image. You do not need to activate `.venv` for Docker commands.

### Start Docker

Open Docker Desktop and wait for its engine to start. Then, from the repository
folder used above, check that both Client and Server information are displayed:

```bash
docker version
```

### Read the Dockerfile

| Instruction | What it does here |
| --- | --- |
| `FROM python:3.14-slim` | Starts with Python 3.14 on a minimal Debian base |
| `ENV ...` | Disables bytecode writes and enables immediate Python log output |
| `WORKDIR /app` | Sets the working folder inside the image |
| `COPY requirements.txt .` | Copies the runtime dependency list first |
| `RUN python -m pip install ...` | Installs dependencies while building the image |
| `RUN useradd ...` | Creates a Linux user with ID 10001 |
| `COPY app/ ./app/` | Copies your application source into the image |
| `USER appuser` | Runs the remaining container commands as that ordinary user |
| `EXPOSE 8000` | Documents which port the app listens on |
| `CMD [...]` | Sets the command that starts the server when a container runs |

Dependencies are copied and installed before the source. When only source changes,
Docker can reuse the dependency layer. Runtime dependencies go into the image;
pytest and HTTPX stay in your local development environment.

The app binds to `0.0.0.0` **inside the container** so forwarded traffic can reach
it. The run command below publishes the port only on your laptop's `127.0.0.1`.
`EXPOSE` alone does not publish a port. We omit `--reload`: each image contains a
fixed copy of the source. The base image tag and transitive dependencies may change
on later builds; this beginner setup is not a fully locked, reproducible build.

### Build an image

```bash
docker build -t cloud-platform:local .
```

`-t` assigns the name `cloud-platform` and tag `local`. The final `.` selects the
current folder as the build context. `.dockerignore` allows only the required
build files and application directory. The first build needs internet access to
download the Python image and packages.

### Run a container

```bash
docker run --rm --name cloud-platform -p 127.0.0.1:8001:8000 cloud-platform:local
```

- `--rm` removes this container when it stops; the image remains available.
- `--name` gives it a recognizable name for logs and stop commands.
- `-p 127.0.0.1:8001:8000` forwards laptop port **8001** to container port **8000**.
  This lets your earlier local server keep using laptop port 8000.
- `cloud-platform:local` selects the image you just built.

Leave that terminal running. In another terminal, check all three routes:

```bash
curl --fail http://127.0.0.1:8001/
curl --fail http://127.0.0.1:8001/health
curl --fail http://127.0.0.1:8001/metrics
```

Expect the same JSON responses and metrics format as the local app. `--fail`
makes curl report an error for HTTP error responses. You can also open
<http://127.0.0.1:8001/docs> in your browser.

### Inspect and stop

```bash
docker ps
docker logs cloud-platform
docker exec cloud-platform id
docker stop cloud-platform
```

`ps` lists running containers, `logs` shows the server's output, and `exec ... id`
checks the running user (expect `uid=10001(appuser)`, not root). `stop` sends the
server a termination signal so it can shut down. You can also press Ctrl+C in the
original run terminal. The JSON-list `CMD` lets the server receive stop signals
directly. Stopping the container resets its in-memory request counter.

### Practice: change, rebuild, rerun

1. Change the welcome message in `app/main.py`.
2. Refresh the container's home page at port 8001. It still shows the old message:
   the running container uses the source copied during its build.
3. Stop the container, run the build command again, and repeat the run command.
4. Refresh port 8001 and observe the new message. Update the corresponding test
   expectation if you keep the change, then run `python -m pytest -q` in `.venv`.

No source folder is mounted into this container, so editing your laptop's files
does not automatically change its code. Environment variables are introduced here
through `ENV` for Python's runtime behavior; the app has no custom configuration yet.

Interview explanation: "I packaged the FastAPI service in a Python image, installed
only runtime dependencies, and ran it as a non-root user. I copied requirements
before source to reuse Docker's build cache. I published a host port to the
container's port and verified the existing health and metrics endpoints."

## Troubleshooting

- **`No module named ...`:** activate `.venv`, install `requirements-dev.txt`,
  and use `python -m ...` so commands use the same interpreter.
- **`Could not import module app.main`:** return to the directory containing
  this README before starting Uvicorn.
- **`Address already in use`:** stop an earlier server with Ctrl+C or use
  `--port 8001`, then use port 8001 in your browser and curl commands.
- **Connection refused:** keep Uvicorn running and check its terminal for errors.
- **Counter unexpectedly resets:** saving a Python file triggers `--reload`.
- **Cannot connect to the Docker daemon:** open Docker Desktop, wait for the
  engine, and retry `docker version` before building.
- **Container name already in use:** check `docker ps -a`; stop the existing
  project container before running another one with the same name.
- **Docker port 8001 is occupied:** change the host side to
  `-p 127.0.0.1:8002:8000`, then browse port 8002. Keep the container side at 8000.
- **Image build cannot download dependencies:** check internet access and the
  package/registry error shown in the build output, then retry the build.
- **Container still shows old code:** rebuild the image, stop the old container,
  and start a new container from the updated image.

## References

- [FastAPI testing guide](https://fastapi.tiangolo.com/tutorial/testing/)
- [Prometheus Python counters](https://prometheus.github.io/client_python/instrumenting/counter/)
- [Docker build best practices](https://docs.docker.com/build/building/best-practices/)
