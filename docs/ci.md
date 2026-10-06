# CI: check code and publish a container image

The workflow lives in `.github/workflows/ci.yml`. GitHub runs it on pushes to
`main`, pull requests targeting `main`, and manual runs from the Actions page.
It runs on GitHub-hosted machines; your laptop and Docker Desktop can be off.

## Follow the workflow

1. Checkout downloads the repository without retaining Git credentials.
2. Setup Python selects Python 3.14 and caches dependency downloads.
3. pip installs `requirements-dev.txt`, including Ruff and pytest.
4. Ruff checks common Python mistakes, import order, and formatting. pytest runs
   the API tests; pip checks dependency compatibility.
5. Docker builds the image and labels it with its source repository and commit.
6. Trivy scans OS and Python packages for known vulnerabilities. Any HIGH or
   CRITICAL result blocks publishing, even when no fix is available. Scanner
   download or execution failures also fail the job. Passing a scan is not proof
   that an image has no vulnerabilities.
7. On `main`, the passing image is saved as an artifact retained for one day.
8. The publish job loads that same image, logs into GHCR, and pushes a commit tag.

`needs: verify` makes publishing depend on successful checks. Only the publish
job has `packages: write`; pull requests never enter it. GitHub supplies the
temporary `GITHUB_TOKEN`, so no personal access token or custom secret is needed
for this workflow. Action references are pinned to commit hashes; update those
and the Trivy version deliberately when upgrading tools.

## What gets published

```text
ghcr.io/saikarthick11/production-cloud-deployment-platform:sha-<full-commit-sha>
```

The full tag is printed in the publish job summary. This phase builds Linux AMD64
on the GitHub runner. Local Apple Silicon images from earlier phases are ARM64;
the registry image needs emulation there. Multi-platform publishing is a later
improvement. New GHCR packages may be private even for public repositories; package
visibility and reader access are separate from successful publication.

This workflow publishes images but does not deploy them to Kubernetes. Your local
Helm release remains on its existing image. Deployment automation comes later.

## Run checks before pushing

From the project root, activate `.venv`, then:

```bash
python -m pip install -r requirements-dev.txt
python -m ruff check .
python -m ruff format --check .
python -m pytest -q
```

`ruff check` detects configured code issues. `ruff format --check` reports formatting
differences without editing files. To apply formatting, run `python -m ruff format .`,
review the diff, then repeat the checks.

After pushing, open the repository's **Actions** tab and choose **Test, scan, and
publish**. Expand each step to read its output. A failure prevents downstream
steps from running; inspect the first failed step before rerunning.

For vulnerability failures, read the affected package and fixed version in the
scan output. Update the dependency or base image and rerun checks. Do not disable
the scan or silently ignore findings to obtain a passing badge. If no fix exists,
publication remains blocked under this policy.

The workflow does not configure branch protection: passing checks are required
for image publication, but repository rules are a separate setting.

References: [GitHub image publishing](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images),
[Trivy container scanning](https://trivy.dev/docs/latest/target/container_image/).
