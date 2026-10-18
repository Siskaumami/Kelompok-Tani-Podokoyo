# ADR 008: Frontend-agnostic REST

Status: Accepted for V1; Flutter client implemented in `apps/mobile`.

## Decision

Keep business rules and permissions in services behind `/api/v1`. React and Flutter are clients; transport/session handling may differ by platform without forking domain logic.

## Rationale

The implemented Flutter client shares the backend contract and invariants instead of rebuilding authoritative domain logic.

## Consequences and change conditions

Native or marketplace adapters must resolve the same Actor and execute the same transactions.