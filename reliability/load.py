"""Generate bounded HTTP traffic inside the practice namespace."""

import concurrent.futures
import time
import urllib.error
import urllib.request


def worker():
    deadline = time.monotonic() + 180
    succeeded = failed = 0
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen("http://reliability-demo/", timeout=3) as response:
                response.read()
                succeeded += 1
        except urllib.error.URLError, TimeoutError:
            failed += 1
    return succeeded, failed


if __name__ == "__main__":
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda _: worker(), range(8)))
    print(f"Successful requests: {sum(r[0] for r in results)}", flush=True)
    print(f"Failed requests: {sum(r[1] for r in results)}", flush=True)
