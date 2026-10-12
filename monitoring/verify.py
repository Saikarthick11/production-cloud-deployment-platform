"""Check dashboard queries through the local Prometheus port-forward."""

import json
import urllib.parse
import urllib.request
from pathlib import Path

dashboard = json.loads(Path("monitoring/dashboard.json").read_text())
for panel in dashboard["panels"]:
    query = urllib.parse.urlencode({"query": panel["targets"][0]["expr"]})
    with urllib.request.urlopen(
        f"http://127.0.0.1:9090/api/v1/query?{query}", timeout=10
    ) as response:
        result = json.load(response)
    if result["status"] != "success" or not result["data"]["result"]:
        raise SystemExit(f"No samples for {panel['title']}; check targets and allow more scrapes.")
    values = [sample["value"][1] for sample in result["data"]["result"]]
    print(f"{panel['title']}: {', '.join(values)}")
