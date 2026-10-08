"""Update only the image settings after both architecture builds pass CI."""

import re
import sys
from pathlib import Path


def promote(text: str, repository: str, tag: str) -> str:
    repository = repository.lower()
    if not re.fullmatch(r"ghcr\.io/[a-z0-9_.-]+/[a-z0-9_.-]+", repository):
        raise ValueError("Expected a GHCR owner/repository")
    if not re.fullmatch(r"sha-[0-9a-f]{40}", tag):
        raise ValueError("Expected a full commit SHA tag")
    for key, value in [("repository", repository), ("tag", tag), ("pullPolicy", "IfNotPresent")]:
        text, count = re.subn(rf"(?m)^  {key}: .*$", f"  {key}: {value}", text)
        if count != 1:
            raise ValueError(f"Expected exactly one image {key} setting")
    return text


if __name__ == "__main__":
    path = Path("gitops/values-local.yaml")
    path.write_text(promote(path.read_text(), sys.argv[1], sys.argv[2]))
