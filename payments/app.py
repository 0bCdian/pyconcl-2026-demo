"""Fake payment gateway with configurable latency."""

import asyncio
import os
import random
import uuid

from fastapi import FastAPI

LATENCY_MS = int(os.environ.get("LATENCY_MS", "150"))

app = FastAPI()


@app.post("/charge")
async def charge():
    await asyncio.sleep(random.uniform(0.5, 1.5) * LATENCY_MS / 1000)
    return {"payment_id": uuid.uuid4().hex}
