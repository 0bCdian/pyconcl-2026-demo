"""Draws the deck's charts from Prometheus (kubectl port-forward to localhost:9090) for a time window of a GKE run."""

import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

import matplotlib

matplotlib.use("svg")
import matplotlib.pyplot as plt

INK, LOSS, GRID = "#111111", "#c8102e", "#dddddd"
OUT = Path(__file__).parent.parent / "slides" / "public" / "charts"
PROMETHEUS = "http://localhost:9090/api/v1/query_range"
DEMO = 'namespace="demo"'

CHARTS = {
    "memory": ("MiB por pod", f'avg by (container) (container_memory_working_set_bytes{{{DEMO}, container=~"bad|good"}}) / 2^20'),
    "served": ("requests OK por segundo", 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"bad|good", expected_response="true"}[30s]))'),
    "throttling": ("% de períodos de CPU frenados", f'100 * sum by (container) (rate(container_cpu_cfs_throttled_periods_total{{{DEMO}, container=~"bad|good"}}[1m])) / sum by (container) (rate(container_cpu_cfs_periods_total{{{DEMO}, container=~"bad|good"}}[1m]))'),
    "ramp": ("requests OK por segundo", 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"good|workers2", expected_response="true"}[30s]))'),
    "ramp_memory": ("MiB en total", f'sum by (container) (container_memory_working_set_bytes{{{DEMO}, container=~"good|workers2"}}) / 2^20'),
}
LABELS = {"bad": ("A", LOSS), "good": ("B", INK), "workers2": ("1 pod × 2 workers", LOSS)}


def series(query: str, start: int, end: int) -> dict[str, list[tuple[float, float]]]:
    url = PROMETHEUS + "?" + urllib.parse.urlencode({"query": query, "start": start, "end": end, "step": 15})
    result = json.load(urllib.request.urlopen(url))["data"]["result"]
    return {next(iter(r["metric"].values())): [(float(t) - start, float(v)) for t, v in r["values"]] for r in result}


def draw(name: str, start: int, end: int) -> None:
    ylabel, query = CHARTS[name]
    fig, ax = plt.subplots(figsize=(8, 4.2))
    for key, points in sorted(series(query, start, end).items()):
        label, color = LABELS[key]
        if name.startswith("ramp") and key == "good":
            label = "2 pods × 1 proceso"
        ax.plot([t / 60 for t, _ in points], [v for _, v in points], color=color, linewidth=3, label=label)
    ax.set_xlabel("minutos", fontsize=13)
    ax.set_ylabel(ylabel, fontsize=13)
    ax.set_ylim(bottom=0)
    ax.grid(color=GRID, linewidth=0.8)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(frameon=False, fontsize=13, loc="best")
    fig.tight_layout()
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / f"{name}.svg")
    print(OUT / f"{name}.svg")


if __name__ == "__main__":
    # Usage: charts.py NAME START END, with START and END as local "YYYY-MM-DD HH:MM:SS"
    name, start, end = sys.argv[1], *(int(datetime.fromisoformat(s).timestamp()) for s in sys.argv[2:4])
    draw(name, start, end)
