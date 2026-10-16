# ADR 005: Historical price/HPP and full economics versions

Status: Accepted for V1.

## Decision

Append immutable economics versions; snapshot sale names, prices, costs and line totals.

## Rationale

Current price/cost changes must not restate past economics.

## Consequences and change conditions

Current product data must never be joined to recalculate a historical report. Effective-until is derived from version history.
