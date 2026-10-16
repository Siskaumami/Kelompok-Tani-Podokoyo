# ADR 007: PWA now, no offline transactions

Status: Accepted for V1.

## Decision

Installable web/PWA with static caching and an offline notice. No API cache, business-write queue, Background Sync or automatic mutation replay.

## Rationale

Simple installation improves mobile access without conflicting physical stock writes.

## Consequences and change conditions

A future offline proposal requires conflict/overselling/idempotency review rather than adding a queue locally.
