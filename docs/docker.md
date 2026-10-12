# Run the app with Docker

[Back to the project](../README.md)

Docker puts the app and its dependencies into one image so the same package can
run on another machine. Open Docker Desktop, then follow these steps from the
project folder.

## How it works

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
| `FROM python:3.14-alpine` | Starts with Python 3.14 on a minimal Alpine base |
| `ENV ...` | Disables bytecode writes and enables immediate Python log output |
| `WORKDIR /app` | Sets the working folder inside the image |
| `COPY requirements.txt .` | Copies the runtime dependency list first |
| `RUN python -m pip install ...` | Installs dependencies while building the image |
| `RUN adduser ...` | Creates a Linux user with ID 10001 |
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

