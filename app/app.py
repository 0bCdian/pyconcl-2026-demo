"""Shop API: product catalog and orders."""

import io
import json
import logging
import os
import sys
import time
import uuid
from contextlib import asynccontextmanager

import asyncpg
import httpx
import numpy as np
import pandas as pd
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

PAYMENTS_URL = os.environ.get("PAYMENTS_URL", "http://payments/charge")
DATABASE_URL = os.environ["DATABASE_URL"]
SHOP_NAME = os.environ["SHOP_NAME"]
CATALOG_URI = os.environ.get("CATALOG_URI")
CATALOG_SIZE = int(os.environ.get("CATALOG_SIZE", "5000"))
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
CATEGORIES = ["libros", "electro", "hogar", "deporte", "juguetes"]


class JsonFormatter(logging.Formatter):
    """One JSON object per line, with the `severity` field Cloud Logging and most log collectors read."""

    def format(self, record):
        entry = {"severity": record.levelname, "logger": record.name, "message": record.getMessage()}
        if record.exc_info:
            entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(entry)


handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logging.basicConfig(level=LOG_LEVEL, handlers=[handler])
log = logging.getLogger("shop")


def generate_catalog() -> pd.DataFrame:
    rng = np.random.default_rng(42)
    return pd.DataFrame(
        {
            "id": np.arange(CATALOG_SIZE),
            "category": rng.choice(CATEGORIES, CATALOG_SIZE),
            "price": rng.integers(990, 99_990, CATALOG_SIZE),
            "stock": rng.integers(0, 50, CATALOG_SIZE),
            "rating": rng.uniform(1, 5, CATALOG_SIZE).round(1),
        }
    )


def download_catalog(uri: str) -> pd.DataFrame:
    """Reads gs://bucket/object with Application Default Credentials: no key handling in the code."""
    from google.cloud import storage

    bucket, _, name = uri.removeprefix("gs://").partition("/")
    for attempt in range(5):
        try:
            data = storage.Client().bucket(bucket).blob(name).download_as_bytes()
            return pd.read_csv(io.BytesIO(data))
        except Exception:
            if attempt == 4:
                raise
            log.warning("catalog download failed, retrying", exc_info=True)
            time.sleep(2**attempt)


catalog = download_catalog(CATALOG_URI) if CATALOG_URI else generate_catalog()
products = catalog.to_dict("records")


class Item(BaseModel):
    product_id: int = Field(ge=0)
    quantity: int = Field(ge=1, le=10)


class Order(BaseModel):
    customer_id: int
    items: list[Item] = Field(min_length=1, max_length=20)


def order_total(order: Order) -> int:
    subtotal = 0
    for item in order.items:
        if item.product_id >= len(products):
            raise HTTPException(404, f"product {item.product_id} not found")
        subtotal += products[item.product_id]["price"] * item.quantity
    bulk_discount = subtotal // 10 if subtotal > 100_000 else 0
    return subtotal - bulk_discount


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with httpx.AsyncClient(timeout=5) as client, asyncpg.create_pool(DATABASE_URL) as pool:
        app.state.payments = client
        app.state.db = pool
        yield


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health():
    return {"ok": True}


@app.get("/products")
async def list_products(
    category: str | None = None, page: int = Query(1, ge=1), size: int = Query(50, ge=1, le=100)
):
    in_stock = [p for p in products if p["stock"] > 0 and category in (None, p["category"])]
    in_stock.sort(key=lambda p: (-p["rating"], p["price"]))
    start = (page - 1) * size
    return in_stock[start : start + size]


@app.post("/orders")
async def create_order(order: Order):
    log.debug("order payload %s", order)
    total = order_total(order)
    order_id = uuid.uuid4()
    response = await app.state.payments.post(
        PAYMENTS_URL,
        json={"order_id": str(order_id), "shop": SHOP_NAME, "customer_id": order.customer_id, "amount": total},
    )
    response.raise_for_status()
    payment_id = response.json()["payment_id"]
    await app.state.db.execute(
        "insert into orders (order_id, shop, customer_id, total, payment_id) values ($1, $2, $3, $4, $5)",
        order_id, SHOP_NAME, order.customer_id, total, payment_id,
    )
    log.info("order customer=%s total=%s", order.customer_id, total)
    return {"order_id": str(order_id), "total": total, "payment_id": payment_id}
