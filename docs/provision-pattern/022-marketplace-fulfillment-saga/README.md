# 022 - Marketplace Fulfillment Saga

Business scenario: a marketplace checkout reserves inventory, captures payment
in a child workflow, quotes shipment, joins the parallel work, and commits the
shipment. If any side-effecting step fails, the workflow routes through an
error boundary and relies on compensation metadata for reverse cleanup.

Provision the child workflow first, then the parent:

1. `payment-capture-child.yaml`
2. `workflow.yaml`

## Runtime Route

Parent route:

`POST /examples/marketplace/checkout`

Child route:

`POST /examples/marketplace/internal/payment-capture`

## Example Request

```json
{
  "checkout_id": "chk_1001",
  "idempotency_key": "chk_1001_attempt_1",
  "customer_id": "cust_1001",
  "amount": 425000,
  "currency": "IDR",
  "items": [
    { "sku": "COF-250", "qty": 2 }
  ],
  "ship_to": {
    "city": "Bandung",
    "country": "ID"
  }
}
```

## Expected Paths

| Path | Condition | Expected behavior |
|---|---|---|
| Success | Reserve, payment capture, shipment quote, and commit all succeed | Returns `status: fulfilled`. |
| Failure | Any side-effecting branch or commit fails | Error edge enters `ErrorBoundary`, waits a short backoff timer, and returns `status: compensation_required`. |

## Feature Coverage

- Parent and child workflows.
- `Parallel` fork and `Join` barrier.
- `SubWorkflow` invocation.
- HTTP Connector side effects with `persistence: ssot`.
- Saga `compensation` metadata on reserve and shipment commit.
- `ErrorBoundary` and error-edge routing.
- `Timer` backoff before failure response.
- EndTrigger response for success and failure.

## Local Mock Contracts

Inventory reserve:

`POST http://127.0.0.1:18022/inventory/reserve`

Payment capture:

`POST http://127.0.0.1:18022/payments/capture`

Shipment quote:

`POST http://127.0.0.1:18022/shipping/quote`

Shipment commit:

`POST http://127.0.0.1:18022/shipping/commit`

Compensation endpoints referenced by metadata:

- `http://127.0.0.1:18022/inventory/release`
- `http://127.0.0.1:18022/shipping/cancel`
