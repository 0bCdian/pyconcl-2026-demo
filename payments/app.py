"""Fake payment gateway with configurable latency, recording every charge."""

import asyncio
import os
import random
import uuid
from contextlib import asynccontextmanager
from datetime import UTC, datetime

import asyncpg
from fastapi import FastAPI
from pydantic import BaseModel

LATENCY_MS = int(os.environ.get("LATENCY_MS", "150"))
DATABASE_URL = os.environ["DATABASE_URL"]
EPOCH = datetime.fromtimestamp(0, UTC)

RECONCILIATION_SQL = """
select s.shop,
       (select count(*) from charges where shop = s.shop and created_at >= $1) as charges,
       (select count(*) from orders where shop = s.shop and created_at >= $1) as orders,
       (select count(*) from charges c
         where c.shop = s.shop and c.created_at >= $1
           and c.created_at < now() - interval '10 seconds'
           and not exists (select 1 from orders o where o.order_id = c.order_id)) as charged_without_order
from (values ('bad'), ('good')) as s(shop)
"""


class Charge(BaseModel):
    order_id: uuid.UUID
    shop: str
    customer_id: int
    amount: int


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with asyncpg.create_pool(DATABASE_URL) as pool:
        app.state.db = pool
        yield


app = FastAPI(lifespan=lifespan)


@app.post("/charge")
async def charge(charge: Charge):
    await asyncio.sleep(random.uniform(0.5, 1.5) * LATENCY_MS / 1000)
    payment_id = uuid.uuid4().hex
    await app.state.db.execute(
        "insert into charges (payment_id, order_id, shop, amount) values ($1, $2, $3, $4)",
        payment_id, charge.order_id, charge.shop, charge.amount,
    )
    return {"payment_id": payment_id}


@app.get("/reconciliation")
async def reconciliation(since: datetime = EPOCH):
    rows = await app.state.db.fetch(RECONCILIATION_SQL, since)
    return {row["shop"]: {k: row[k] for k in ("charges", "orders", "charged_without_order")} for row in rows}
