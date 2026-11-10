"""Checks that a tap sends the identical order to both sides and that stats count ok/lost."""

import asyncio
import json

import httpx

import app as arena


def test_same_order_to_both_sides_and_stats_count():
    seen = {"A": [], "B": []}

    def shop(side, status):
        def handler(request: httpx.Request) -> httpx.Response:
            seen[side].append(json.loads(request.content))
            return httpx.Response(status, json={"order_id": f"order-{side}", "total": 1, "payment_id": "p"})
        return httpx.AsyncClient(base_url="http://shop", transport=httpx.MockTransport(handler))

    arena.clients.update(A=shop("A", 500), B=shop("B", 200))
    results = asyncio.run(arena.play(product_id=7))

    assert seen["A"] == seen["B"] and len(seen["A"]) == 1
    assert seen["A"][0]["items"] == [{"product_id": 7, "quantity": 1}]
    assert results["A"]["ok"] is False and results["B"]["order_id"] == "order-B"
    stats = arena.stats()
    assert (stats["A"]["ok"], stats["A"]["lost"]) == (0, 1)
    assert (stats["B"]["ok"], stats["B"]["lost"]) == (1, 0)
    assert stats["A"]["charged_without_order"] is None
