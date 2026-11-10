"""Arena: sends every tap as the same order to two versions of the shop and streams which ones went through."""

import asyncio
import base64
import io
import json
import logging
import os
import random
import secrets
import time
from collections import deque
from contextlib import asynccontextmanager
from pathlib import Path

import httpx
import segno
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

SIDES = {
    side: {"url": os.environ.get(f"{side}_URL", url), "name": os.environ.get(f"{side}_NAME", name)}
    for side, url, name in [("A", "http://bad", "mala"), ("B", "http://good", "buena")]
}
GRID = int(os.environ.get("GRID", "64"))
TAP_TIMEOUT = float(os.environ.get("TAP_TIMEOUT", "2"))
DEVICE_RATE = float(os.environ.get("DEVICE_RATE", "5"))
MAX_RATE = float(os.environ.get("MAX_RATE", "300"))
CATALOG_SIZE = int(os.environ.get("CATALOG_SIZE", "5000"))
PUBLIC_URL = os.environ.get("PUBLIC_URL")
ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN") or secrets.token_urlsafe(16)
STATIC = Path(__file__).parent / "static"

CELLS = GRID * GRID
EMPTY, PAINTED, LOST = 0, 1, 2
STATS_WINDOW_S = 10

logging.basicConfig(level="INFO", format="%(message)s")
logging.getLogger("httpx").setLevel(logging.WARNING)
log = logging.getLogger("arena")


class TokenBucket:
    def __init__(self, rate: float, burst: float):
        self.rate, self.burst = rate, burst
        self.tokens, self.updated = burst, time.monotonic()

    def take(self) -> bool:
        now = time.monotonic()
        self.tokens = min(self.burst, self.tokens + (now - self.updated) * self.rate)
        self.updated = now
        if self.tokens < 1:
            return False
        self.tokens -= 1
        return True


reveal_order = random.Random(2026).sample(range(CELLS), CELLS)
state = {"next": 0, "round": 0, "revealed": False, "autoplay": 0.0}
canvas = {side: bytearray(CELLS) for side in SIDES}
pending = {side: [] for side in SIDES}
recent = {side: deque() for side in SIDES}
totals = {side: {"ok": 0, "lost": 0} for side in SIDES}
in_flight = dict.fromkeys(SIDES, 0)
subscribers: set[asyncio.Queue] = set()
global_bucket = TokenBucket(MAX_RATE, MAX_RATE)
device_buckets: dict[str, TokenBucket] = {}
clients: dict[str, httpx.AsyncClient] = {}


def random_order() -> dict:
    items = [
        {"product_id": random.randrange(CATALOG_SIZE), "quantity": random.randint(1, 3)}
        for _ in range(random.randint(1, 4))
    ]
    return {"customer_id": random.randrange(1_000_000), "items": items}


async def send(side: str, order: dict, cell: int, round_: int) -> dict:
    in_flight[side] += 1
    start = time.perf_counter()
    try:
        response = await clients[side].post("/orders", json=order)
        ok = response.status_code == 200
    except httpx.HTTPError:
        ok = False
    finally:
        in_flight[side] -= 1
    if round_ != state["round"]:
        return {"ok": ok, "ms": 0}
    latency_ms = round((time.perf_counter() - start) * 1000)
    recent[side].append((time.monotonic(), ok, latency_ms))
    totals[side]["ok" if ok else "lost"] += 1
    canvas[side][cell] = PAINTED if ok else LOST
    pending[side].append((cell, canvas[side][cell]))
    return {"ok": ok, "ms": latency_ms}


async def play() -> dict:
    cell = reveal_order[state["next"] % CELLS]
    state["next"] += 1
    order = random_order()
    results = await asyncio.gather(*(send(side, order, cell, state["round"]) for side in SIDES))
    return dict(zip(SIDES, results))


def labels() -> dict:
    return {side: SIDES[side]["name"] if state["revealed"] else None for side in SIDES}



def stats() -> dict:
    cutoff = time.monotonic() - STATS_WINDOW_S
    out = {}
    for side, window in recent.items():
        while window and window[0][0] < cutoff:
            window.popleft()
        latencies = sorted(ms for _, _, ms in window)
        failed = sum(1 for _, ok, _ in window if not ok)
        out[side] = {
            **totals[side],
            "rate": round(len(window) / STATS_WINDOW_S, 1),
            "error_pct": round(100 * failed / len(window), 1) if window else 0,
            "p95_ms": latencies[int(0.95 * (len(latencies) - 1))] if latencies else None,
            "in_flight": in_flight[side],
        }
    return out


def snapshot() -> dict:
    return {
        "grid": GRID,
        "snapshot": {side: base64.b64encode(canvas[side]).decode() for side in SIDES},
        "labels": labels(),
        "autoplay": state["autoplay"],
        "stats": stats(),
    }


def publish(message: dict) -> None:
    data = f"data: {json.dumps(message)}\n\n"
    for queue in list(subscribers):
        try:
            queue.put_nowait(data)
        except asyncio.QueueFull:
            subscribers.discard(queue)


async def broadcast_forever() -> None:
    ticks = 0
    while True:
        await asyncio.sleep(0.1)
        cells = {side: pending[side] for side in SIDES}
        for side in SIDES:
            pending[side] = []
        publish({"cells": cells, "stats": stats(), "labels": labels(), "autoplay": state["autoplay"]})
        ticks += 1
        if ticks % 100 == 0:
            idle = time.monotonic() - 60
            for device in [d for d, b in device_buckets.items() if b.updated < idle]:
                del device_buckets[device]


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
    for side, config in SIDES.items():
        clients[side] = httpx.AsyncClient(
            base_url=config["url"],
            timeout=TAP_TIMEOUT,
            limits=httpx.Limits(max_connections=None, max_keepalive_connections=200),
        )
    tasks = [asyncio.create_task(broadcast_forever()), asyncio.create_task(autoplay_forever())]
    log.info("screen: /screen?token=%s", ADMIN_TOKEN)
    yield
    for task in tasks:
        task.cancel()
    for client in clients.values():
        await client.aclose()


app = FastAPI(lifespan=lifespan)
app.mount("/static", StaticFiles(directory=STATIC), name="static")


class Tap(BaseModel):
    device: str = Field(min_length=8, max_length=64)


class Control(BaseModel):
    autoplay: float | None = Field(None, ge=0, le=1000)
    revealed: bool | None = None
    reset: bool = False


@app.get("/health")
async def health():
    return {"ok": True}


@app.get("/stats")
async def current_stats():
    return stats()


@app.get("/")
async def play_page():
    return FileResponse(STATIC / "play.html")


@app.get("/screen")
async def screen_page():
    return FileResponse(STATIC / "screen.html")


@app.get("/qr.svg")
async def qr(request: Request):
    url = PUBLIC_URL or str(request.base_url)
    svg = io.BytesIO()
    segno.make(url, error="m").save(svg, kind="svg", scale=8, border=2, dark="#1d1846", light="#ffffff")
    return Response(svg.getvalue(), media_type="image/svg+xml")


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


@app.post("/tap")
async def tap(body: Tap):
    bucket = device_buckets.setdefault(body.device, TokenBucket(DEVICE_RATE, DEVICE_RATE * 2))
    if not bucket.take():
        raise HTTPException(429, "slow down")
    if not global_bucket.take():
        raise HTTPException(429, "arena busy")
    return {"results": await play(), "labels": labels()}


@app.post("/admin")
async def admin(control: Control, authorization: str = Header("")):
    if not secrets.compare_digest(authorization.encode(), f"Bearer {ADMIN_TOKEN}".encode()):
        raise HTTPException(401)
    if control.autoplay is not None:
        state["autoplay"] = control.autoplay
    if control.revealed is not None:
        state["revealed"] = control.revealed
    if control.reset:
        state["next"] = 0
        state["round"] += 1
        for side in SIDES:
            canvas[side][:] = bytes(CELLS)
            pending[side].clear()
            recent[side].clear()
            totals[side].update(ok=0, lost=0)
        publish(snapshot())
    return {"autoplay": state["autoplay"], "revealed": state["revealed"]}
