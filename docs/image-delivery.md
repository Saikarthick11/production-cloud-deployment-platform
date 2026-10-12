# Where the image goes

[Back to the project](../README.md)

Our container images live in **GitHub Container Registry (GHCR)**. Think of it
as the place Kubernetes downloads the packaged app from.

## From a change to a running app

1. You push a code change to GitHub.
2. GitHub Actions builds and checks two images: one for AMD64 and one for ARM64.
3. Passing images are published under a shared tag tied to the source commit.
4. The workflow updates the image tag in `gitops/values-local.yaml`.
5. Argo CD sees that Git change, and Kubernetes downloads the matching image.

Publishing uses the images that already passed the checks; it does not rebuild
them after scanning. If a newer commit has arrived, the older run skips promotion
instead of replacing the newer configuration.

## Why is there another commit?

You may see a commit named **Deploy scanned image ...** after your own commit.
The workflow creates it to record which image should run. That automated commit
does not start another build loop, but Argo CD can still see it.

## Are we using Google Artifact Registry?

Not yet. The Terraform files describe a future Artifact Registry repository.
The working pipeline still publishes to GHCR.

[Read the detailed delivery guide](image-delivery-walkthrough.md) for image tags,
verification commands, and troubleshooting.
