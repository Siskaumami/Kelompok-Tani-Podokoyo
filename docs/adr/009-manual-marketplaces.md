# ADR 009: Manual marketplace sales in V1

Status: Accepted for V1.

## Decision

Support Shopee/Tokopedia/WhatsApp purchase links and channel-neutral manual sale records; marketplace APIs are deferred.

## Rationale

API synchronization and checkout are outside the delivery scope and would add unnecessary credentials/operational complexity.

## Consequences and change conditions

Future adapters create equivalent internal sales with proper idempotency; they do not redefine Sale.
