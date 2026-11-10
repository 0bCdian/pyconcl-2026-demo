import math
import os
from pathlib import Path


def container_cpus() -> int:
    """Whole CPUs granted by the cgroup v2 quota; 1 when the container has no CPU limit."""
    try:
        quota, period = Path("/sys/fs/cgroup/cpu.max").read_text().split()
    except (OSError, ValueError):
        return 1
    if quota == "max":
        return 1
    return max(1, math.ceil(int(quota) / int(period)))


bind = "0.0.0.0:8000"
workers = int(os.environ.get("WEB_CONCURRENCY", container_cpus()))
worker_class = "uvicorn_worker.UvicornWorker"
