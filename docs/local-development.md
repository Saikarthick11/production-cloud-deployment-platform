# Run and understand the Python app

[Back to the project](../README.md)

Start here if you want to run the app without Docker or Kubernetes.
Use Python 3.14 and run the commands from the project folder.

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
`-q` makes its output shorter. Expect **9 passed** (six API tests and three image-promotion tests). `pip check` checks installed
dependencies for missing packages and incompatible version requirements.
The server can be stopped: tests run their own in-process app.

With the verified dependency versions, Starlette emits one deprecation warning
about its HTTPX-backed TestClient. All nine tests pass; the warning concerns a
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
combine counters across multiple workers or machines. Our monitoring setup collects these metrics from Kubernetes. You can also view
this endpoint directly without starting Prometheus.

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

