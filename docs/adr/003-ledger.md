# ADR 003: Append-only inventory ledger

Status: Accepted for V1.

## Decision

Every stock change has a source event; triggers maintain a guarded balance and revision cache.

## Rationale

A mutable stock number cannot explain corrections or support stale-count detection.

## Consequences and change conditions

All new stock workflows must emit movements in the same transaction and retain source history.
