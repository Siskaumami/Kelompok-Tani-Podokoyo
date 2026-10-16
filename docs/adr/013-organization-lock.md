# ADR 013: Organization-level transaction mutex and idempotency

Status: Accepted for V1.

## Decision

Lock organization before all mutations and bind durable idempotency responses to actor/key/operation/canonical input.

## Rationale

Simple total ordering prevents cross-domain races at expected village-group volume.

## Consequences and change conditions

Hot organizations may serialize writes; per-item alternatives require a complete lock-order/capacity review.
