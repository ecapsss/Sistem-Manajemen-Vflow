#!/usr/bin/env python3
import json
import sys


def quote(body):
    items = body.get("items") or []
    subtotal = 0
    for item in items:
        price = int(item.get("unit_price_cents") or 0)
        qty = int(item.get("qty") or 0)
        subtotal += price * qty

    currency = body.get("currency") or "IDR"
    order_id = body.get("order_id") or "unknown"
    discount = 0
    if subtotal >= 1_000_000:
        discount = int(subtotal * 0.05)
    tax = int((subtotal - discount) * 0.11)
    final_price = subtotal - discount + tax
    return {
        "status": "quoted",
        "order_id": order_id,
        "currency": currency,
        "subtotal_cents": subtotal,
        "discount_cents": discount,
        "tax_cents": tax,
        "final_price_cents": final_price,
        "_sidecar": "pricing_sidecar",
    }


def main():
    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
            body = msg.get("body") or msg
            if not isinstance(body, dict):
                body = {}
            sys.stdout.write(json.dumps(quote(body), sort_keys=True) + "\n")
            sys.stdout.flush()
        except Exception as exc:
            sys.stdout.write(json.dumps({"error": str(exc)}) + "\n")
            sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
