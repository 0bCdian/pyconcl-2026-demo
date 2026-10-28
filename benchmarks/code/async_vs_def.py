"""Same /orders endpoint written three ways; ENDPOINT picks one, THREADS sizes the threadpool used by def endpoints."""

import os
from contextlib import asynccontextmanager

import anyio
import httpx
import requests
from fastapi import FastAPI

PAYMENTS_URL = os.environ.get("PAYMENTS_URL", "http://127.0.0.1:9000/charge")
ENDPOINT = os.environ["ENDPOINT"]
THREADS = int(os.environ.get("THREADS", "40"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    anyio.to_thread.current_default_thread_limiter().total_tokens = THREADS
    yield


app = FastAPI(lifespan=lifespan)
client = httpx.AsyncClient(timeout=5)

if ENDPOINT == "async-blocking":

    @app.post("/orders")
    async def create_order():
        return requests.post(PAYMENTS_URL, timeout=5).json()

elif ENDPOINT == "def":

    @app.post("/orders")
    def create_order():
        return requests.post(PAYMENTS_URL, timeout=5).json()

else:

    @app.post("/orders")
    async def create_order():
        return (await client.post(PAYMENTS_URL)).json()
