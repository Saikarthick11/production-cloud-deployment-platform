# Production Cloud Deployment Platform

I built this project to learn what happens between writing an application and
keeping it running. It takes a small Python API through testing, packaging,
deployment, and monitoring.

The app is deliberately simple. The interesting part is how a code change gets
tested, becomes a Docker image, and reaches Kubernetes automatically.

## What problem does it solve?

Deploying by hand means repeating the same steps and remembering what to check.
This project puts those steps into a repeatable process. It is a learning example
for developers who want to understand how a small service can be delivered and
monitored. It is not a service used by real customers.

## What happens when I push code?

1. **Check it.** GitHub Actions runs the tests and checks the Python code.
2. **Package it.** Docker builds images for AMD64 and ARM64 machines.
3. **Scan it.** Trivy checks for known vulnerabilities. High or critical findings
   stop the release.
4. **Store it.** Passing images go to GitHub Container Registry (GHCR).
5. **Deploy it.** The workflow saves the new image tag in Git. Argo CD sees that
   change and updates the app in Kubernetes.
6. **Watch it.** Prometheus collects measurements, and Grafana displays them.

```text
Code → GitHub Actions → GHCR → Argo CD → Kubernetes
                                           ↓
                                   Prometheus + Grafana
```

Argo CD also follows deployment settings pushed to Git. Those settings can sync
before CI finishes; the image promotion step is what waits for a passing build.

## What works today?

| Part | Current state |
| --- | --- |
| Python API | Three endpoints, with automated tests |
| Docker and GitHub Actions | Build, test, scan, and publish images |
| Kubernetes and Argo CD | Deploy the app in a local kind cluster |
| Monitoring | Local Prometheus and Grafana dashboard |
| Reliability practice | Tested scaling from 1 to 3 pods, pod replacement, and rollback |
| GCP Terraform | Configuration validated; no cloud resources created |

Kubernetes runs on my laptop, so Docker Desktop needs to be running. GitHub
Actions and GHCR run on GitHub. Autoscaling is enabled in a separate practice
app; the main GitOps app still uses a fixed replica count.

## Try the app first

You only need **Python 3.14** for this part. On macOS or Linux:

```bash
git clone https://github.com/Saikarthick11/production-cloud-deployment-platform.git
cd production-cloud-deployment-platform
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Already have the project? Open that folder and skip cloning. The virtual
environment keeps this project's packages separate from your other projects.

Open [the app](http://127.0.0.1:8000/) or [the API docs](http://127.0.0.1:8000/docs).
Press **Ctrl+C** to stop the server.

| Address | What you get |
| --- | --- |
| `/` | A welcome message; each visit increases a counter |
| `/health` | A simple response showing the app can answer requests |
| `/metrics` | The request counter in a format Prometheus can read |

Run the tests with the virtual environment activated:

```bash
python -m pytest -q
```

## Explore one part at a time

You do not need to run every guide just to try the app.

| I want to… | Start here |
| --- | --- |
| Understand the Python code and tests | [Local development](docs/local-development.md) |
| Package the app | [Docker](docs/docker.md) |
| Learn how Kubernetes keeps it running | [Kubernetes](k8s/README.md) |
| Reuse deployment settings | [Helm](helm/cloud-platform/README.md) |
| Understand the automated checks | [GitHub Actions](docs/ci.md) |
| Follow an image from build to deployment | [Image delivery](docs/image-delivery.md) |
| Deploy changes from Git | [Argo CD](gitops/README.md) |
| Open the dashboard | [Monitoring](monitoring/README.md) |
| Try scaling and recovery | [Reliability](reliability/README.md) |
| Explore the future GCP setup | [Terraform](terraform/README.md) |

## What I learned

The main lesson was connecting the tools: making sure the image that passed the
checks is the one being deployed, keeping deployment settings in Git, and using
metrics to see how the app behaves.

In the local reliability exercise, the app scaled up under traffic, replaced a
deleted pod, and recovered from a bad image rollout. The [recorded results](reliability/RESULTS.md)
explain what was tested. This is still a learning setup on one machine, not a
highly available production service.
