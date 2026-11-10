#!/bin/bash
# Pool sizes the standard library derives from the node's cores instead of cpu.max, with and without PYTHON_CPU_COUNT=1.
# Usage: pools.sh
cd "$(dirname "$0")/../.."
PROBE='
import os, multiprocessing
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
with multiprocessing.Pool() as pool:
    procs = pool._processes
print(f"cpu_count={os.cpu_count()} ThreadPoolExecutor={ThreadPoolExecutor()._max_workers} ProcessPoolExecutor={ProcessPoolExecutor()._max_workers} multiprocessing.Pool={procs}")'
kubectl -n demo exec deploy/bad -- python -c "$PROBE"
kubectl -n demo exec deploy/bad -- env PYTHON_CPU_COUNT=1 python -c "$PROBE"
