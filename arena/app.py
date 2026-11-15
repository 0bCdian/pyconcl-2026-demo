"""Arena: sends the same order to two versions of the shop and streams which ones went through."""

import asyncio
import json
import logging
import os
import random
import secrets
import time
from collections import deque
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from pathlib import Path

import httpx
from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

SIDES = {side: os.environ.get(f"{side}_URL", url) for side, url in [("A", "http://bad"), ("B", "http://good")]}
REQUEST_TIMEOUT = float(os.environ.get("REQUEST_TIMEOUT", "2"))
CATALOG_SIZE = int(os.environ.get("CATALOG_SIZE", "5000"))
PAYMENTS_URL = os.environ.get("PAYMENTS_URL", "http://payments")
SHOP_NAMES = {"A": os.environ.get("A_SHOP", "bad"), "B": os.environ.get("B_SHOP", "good")}
ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN") or secrets.token_urlsafe(16)
STATIC = Path(__file__).parent / "static"

STATS_WINDOW_S = 10

logging.basicConfig(level="INFO", format="%(message)s")
logging.getLogger("httpx").setLevel(logging.WARNING)
log = logging.getLogger("arena")


state = {"round": 0, "autoplay": 0.0, "since": datetime.now(UTC)}
recent = {side: deque() for side in SIDES}
totals = {side: {"ok": 0, "lost": 0} for side in SIDES}
in_flight = dict.fromkeys(SIDES, 0)
reconciliation: dict[str, dict | None] = dict.fromkeys(SIDES)
subscribers: set[asyncio.Queue] = set()
clients: dict[str, httpx.AsyncClient] = {}
payments_client: httpx.AsyncClient


def random_order() -> dict:
    items = [
        {"product_id": random.randrange(CATALOG_SIZE), "quantity": random.randint(1, 3)}
        for _ in range(random.randint(1, 4))
    ]
    return {"customer_id": random.randrange(1_000_000), "items": items}


async def send(side: str, order: dict, round_: int) -> dict:
    in_flight[side] += 1
    start = time.perf_counter()
    order_id = None
    try:
        response = await clients[side].post("/orders", json=order)
        ok = response.status_code == 200
        if ok:
            order_id = response.json().get("order_id")
    except (httpx.HTTPError, ValueError):
        ok = False
    finally:
        in_flight[side] -= 1
    latency_ms = round((time.perf_counter() - start) * 1000)
    if round_ == state["round"]:
        recent[side].append((time.monotonic(), ok, latency_ms))
        totals[side]["ok" if ok else "lost"] += 1
    return {"ok": ok, "ms": latency_ms, "order_id": order_id}


async def play() -> dict:
    order = random_order()
    results = await asyncio.gather(*(send(side, order, state["round"]) for side in SIDES))
    return dict(zip(SIDES, results))


def stats() -> dict:
    cutoff = time.monotonic() - STATS_WINDOW_S
    out = {}
    for side, window in recent.items():
        while window and window[0][0] < cutoff:
            window.popleft()
        latencies = sorted(ms for _, ok, ms in window if ok)
        failed = sum(1 for _, ok, _ in window if not ok)
        out[side] = {
            **totals[side],
            "rate": round(sum(1 for _, ok, _ in window if ok) / STATS_WINDOW_S, 1),
            "error_pct": round(100 * failed / len(window), 1) if window else 0,
            "p95_ms": latencies[int(0.95 * (len(latencies) - 1))] if latencies else None,
            "in_flight": in_flight[side],
            "charges": (reconciliation[side] or {}).get("charges"),
            "charged_without_order": (reconciliation[side] or {}).get("charged_without_order"),
        }
    return out


def snapshot() -> dict:
    return {"autoplay": state["autoplay"], "stats": stats()}


def publish(message: dict) -> None:
    data = f"data: {json.dumps(message)}\n\n"
    for queue in list(subscribers):
        try:
            queue.put_nowait(data)
        except asyncio.QueueFull:
            subscribers.discard(queue)


async def broadcast_forever() -> None:
    while True:
        await asyncio.sleep(0.1)
        publish(snapshot())


async def reconcile_forever() -> None:
    while True:
        await asyncio.sleep(1)
        try:
            response = await payments_client.get("/reconciliation", params={"since": state["since"].isoformat()})
            response.raise_for_status()
            report = response.json()
            for side, shop in SHOP_NAMES.items():
                reconciliation[side] = report[shop]
        except (httpx.HTTPError, ValueError, KeyError, TypeError):
            log.warning("reconciliation unavailable")


async def autoplay_forever() -> None:
    running = set()
    while True:
        if state["autoplay"] <= 0:
            await asyncio.sleep(0.1)
            continue
        task = asyncio.create_task(play())
        running.add(task)
        task.add_done_callback(running.discard)
        await asyncio.sleep(1 / state["autoplay"])


@asynccontextmanager
async def lifespan(app: FastAPI):
    for side, url in SIDES.items():
        clients[side] = httpx.AsyncClient(
            base_url=url,
            timeout=REQUEST_TIMEOUT,
            limits=httpx.Limits(max_connections=None, max_keepalive_connections=200),
        )
    global payments_client
    payments_client = httpx.AsyncClient(base_url=PAYMENTS_URL, timeout=2)
    tasks = [
        asyncio.create_task(task())
        for task in (broadcast_forever, autoplay_forever, reconcile_forever)
    ]
    log.info("screen: /screen?token=%s", ADMIN_TOKEN)
    yield
    for task in tasks:
        task.cancel()
    for client in [*clients.values(), payments_client]:
        await client.aclose()


app = FastAPI(lifespan=lifespan)
app.mount("/static", StaticFiles(directory=STATIC), name="static")


class Control(BaseModel):
    autoplay: float | None = Field(None, ge=0, le=1000)
    reset: bool = False


@app.get("/health")
async def health():
    return {"ok": True}


@app.get("/stats")
async def current_stats():
    return stats()


@app.get("/screen")
async def screen_page():
    return FileResponse(STATIC / "screen.html")


@app.get("/events")
async def events():
    queue = asyncio.Queue(maxsize=50)
    subscribers.add(queue)

    async def stream():
        try:
            yield f"data: {json.dumps(snapshot())}\n\n"
            while True:
                yield await queue.get()
        finally:
            subscribers.discard(queue)

    return StreamingResponse(stream(), media_type="text/event-stream", headers={"Cache-Control": "no-cache"})


@app.post("/admin")
async def admin(control: Control, authorization: str = Header("")):
    if not secrets.compare_digest(authorization.encode(), f"Bearer {ADMIN_TOKEN}".encode()):
        raise HTTPException(401)
    if control.autoplay is not None:
        state["autoplay"] = control.autoplay
    if control.reset:
        state["round"] += 1
        state["since"] = datetime.now(UTC)
        for side in SIDES:
            recent[side].clear()
            totals[side].update(ok=0, lost=0)
            reconciliation[side] = None
        publish(snapshot())
    return {"autoplay": state["autoplay"]}
