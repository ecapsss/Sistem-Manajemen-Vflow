# 021 - Payments Risk Routing

Business scenario: a payment authorization request is validated, scored by
VDICL rules, routed to a low-risk authorization rail, routed to step-up
authentication, or declined before any side effect.

This example documents the side-effect posture explicitly: payment connectors
must be idempotent and `persistence: ssot` because retries and operator retry
can otherwise duplicate authorizations.

## Runtime Route

`POST /examples/payments/authorize`

## Example Request

```json
{
  "payment_id": "pay_1001",
  "idempotency_key": "pay_1001_attempt_1",
  "amount": 125000,
  "currency": "IDR",
  "card_bin": "411111",
  "country": "ID",
  "merchant_category": "coffee"
}
```

## Expected Paths

| Path | Condition | Expected behavior |
|---|---|---|
| Authorize | `risk_result.decision == "ACCEPT"` | Calls the local payment auth mock and returns `status: authorized`. |
| Step-up | `risk_result.decision == "CHALLENGE_MFA"` | Calls the local 3DS mock and returns `status: challenge_required`. |
| Decline | Default route | Does not call external payment rails and returns `status: declined`. |
| Failure | Payment connector fails | Error edge returns `status: authorization_failed`. |

## Feature Coverage

- Webhook trigger with a route-level rate-limit hint.
- Validate activity for payment payload.
- VRule / VDICL business decisioning.
- Exclusive routing by rule decision.
- HTTP Connector with explicit retry policy and `persistence: ssot`.
- Side-effect warning documented in the example itself.
- Error edge for payment rail failure.

`rules/payment_risk_routing_v1.vdicl` and
`schemas/payment_risk_fact_v1.yaml` are used by the live-safe smoke harness to
compile the actual VDICL pack before triggering this workflow.

## Local Mock Contracts

Authorization mock:

`POST http://127.0.0.1:18021/payments/authorize`

Expected mock response:

```json
{
  "authorization_id": "auth_021_001",
  "approved": true
}
```

3DS mock:

`POST http://127.0.0.1:18021/payments/3ds/challenge`

Expected mock response:

```json
{
  "challenge_id": "3ds_021_001",
  "redirect_url": "https://issuer.test/challenge/3ds_021_001"
}
```
