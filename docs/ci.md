# GitHub Actions: check each change

[Back to the project](../README.md)

When code reaches GitHub, this workflow checks it and builds a container image.
It runs on GitHub's machines, so your laptop can be switched off.

## What gets checked?

- Ruff checks Python code and formatting.
- pytest checks the app and the image-update script.
- Docker builds the app for AMD64 and ARM64 machines.
- A container is started to check that the endpoints respond.
- Trivy scans for known vulnerabilities. High or critical findings stop publication.

Both image builds must pass before the workflow publishes them to GHCR. On
`main`, it then saves the new image tag in Git so Argo CD can deploy it.
Pull requests run checks but do not publish images.

## Where do I see the result?

Open the repository's [Actions page](https://github.com/Saikarthick11/production-cloud-deployment-platform/actions).
Choose a run, then open a job to read its output. If it fails, start with the first
failed step. A successful scan means it passed that scan's checks, not that the
image is guaranteed to have no vulnerabilities.

The workflow is in `.github/workflows/ci.yml`.

[Read the full workflow guide](ci-walkthrough.md) for permissions, setup,
troubleshooting, and the individual steps.
