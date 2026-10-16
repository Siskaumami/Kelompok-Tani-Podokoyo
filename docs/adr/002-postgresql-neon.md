# ADR 002: PostgreSQL / Neon and explicit Drizzle SQL

Status: Accepted for V1.

## Decision

Use PostgreSQL constraints, triggers, row locks, transactions and checksummed SQL migrations; Drizzle node-postgres executes parameterized SQL.

## Rationale

Relational organization integrity and inventory/financial atomicity are central requirements. Explicit SQL keeps locks visible.

## Consequences and change conditions

Migration/runtime roles must be separate; no production PGlite fallback or browser database access.
