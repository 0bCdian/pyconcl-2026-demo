"""Stand-in for an external service that answers in about 150 ms."""

import asyncio
import random

from fastapi import FastAPI

app = FastAPI()


@app.post("/charge")
async def charge():
    await asyncio.sleep(random.uniform(0.075, 0.225))
    return {"payment_id": "stub"}
