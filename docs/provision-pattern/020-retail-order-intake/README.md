# 020 - Retail Order Intake

Business scenario: a storefront receives a cart, validates the payload,
normalizes the order, routes high-value carts to review, and reserves inventory
for normal carts.

This is the first proper business example after the schema matrices. It is not
only a node catalog: it documents the expected request, response paths, and
side-effect boundary.

## Runtime Route

`POST /examples/retail/orders`

## Example Request

```json
{
  "customer_id": "cust_1001",
  "currency": "IDR",
  "subtotal": 425000,
  "items": [
    { "sku": "COF-250", "qty": 2, "unit_price": 120000 },
    { "sku": "MUG-001", "qty": 1, "unit_price": 185000 }
  ]
}
```

## Expected Paths

| Path | Condition | Expected behavior |
|---|---|---|
| Accepted | Valid payload and `subtotal < 1000000` | Calls the local inventory mock and responds with `status: accepted`. |
| Review | Valid payload and `subtotal >= 1000000` | Does not reserve inventory; responds with `status: manual_review`. |
| Rejected | Validate activity fails | Uses the error edge and responds with `status: rejected`. |

## Feature Coverage

- Webhook trigger and EndTrigger response.
- JSON-schema-like `Validate` activity.
- `Transform` data shaping with V-CEL mappings.
- `LoopForEach` for order-line iteration shape.
- `Exclusive` routing for business decisioning.
- HTTP `Connector` with `persistence: ssot` for inventory reservation.
- Error edge from validation failure.

## Local Mock Contract

The inventory connector expects a local mock when running the workflow end to
end:

`POST http://127.0.0.1:18020/inventory/reserve`

Expected mock response:

```json
{
  "reservation_id": "resv_020_001",
  "expires_in_seconds": 900
}
```
