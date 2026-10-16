# ADR 008: Frontend-agnostic REST

Status: Accepted for V1.

## Decision

Keep business rules and permissions in services behind /api/v1. React is one client; native auth transport may be added separately.

## Rationale

Future Flutter should share backend, schema and invariants instead of rebuilding domain logic.

## Consequences and change conditions

Native or marketplace adapters must resolve the same Actor and execute the same transactions.
