"""Same /products endpoint with different logging; LOG_MODE picks one."""

import json
import logging
import logging.handlers
import os
import queue

import numpy as np
import pandas as pd
from fastapi import FastAPI

LOG_MODE = os.environ["LOG_MODE"]
rng = np.random.default_rng(42)
products = pd.DataFrame(
    {"id": np.arange(5000), "price": rng.integers(990, 99_990, 5000), "rating": rng.uniform(1, 5, 5000).round(1)}
).to_dict("records")

log = logging.getLogger("shop")
if LOG_MODE == "lazy":
    log_queue = queue.SimpleQueue()
    logging.handlers.QueueListener(log_queue, logging.StreamHandler()).start()
    logging.basicConfig(level=logging.INFO, handlers=[logging.handlers.QueueHandler(log_queue)])
else:
    logging.basicConfig(level=logging.INFO)

app = FastAPI()


@app.get("/products")
async def list_products():
    items = sorted(products, key=lambda p: (-p["rating"], p["price"]))[:50]
    if LOG_MODE == "eager-debug":
        log.debug(f"sorted catalog: {json.dumps(products)}")
    elif LOG_MODE == "payload":
        log.info(f"response: {json.dumps(items)}")
    elif LOG_MODE == "lazy":
        log.debug("sorted catalog: %s", products)
        log.info("listed %d products", len(items))
    return items
