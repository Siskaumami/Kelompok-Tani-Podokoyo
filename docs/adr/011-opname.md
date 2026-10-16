# ADR 011: Simple physical count, rigorous baseline

Status: Accepted for V1.

## Decision

One active count/item; snapshot quantity and revision; reject stale completion; explicit refresh/recount; reasoned adjustment movement.

## Rationale

Simple operator language can coexist with strong concurrency protection.

## Consequences and change conditions

Do not silently refresh baseline, overwrite balances or add mandatory approval ceremony.
