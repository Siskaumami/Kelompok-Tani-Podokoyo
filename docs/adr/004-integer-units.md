# ADR 004: Grams and integer Rupiah

Status: Accepted for V1.

## Decision

Store raw grams, finished integer units and integer Rupiah in BIGINT. JSON uses decimal strings; calculations use BigInt and explicit half-up raw pricing.

## Rationale

Binary floats and JavaScript Number cannot safely represent every persisted amount.

## Consequences and change conditions

UI conversion must reject ambiguous thousand separators and never use parseFloat for authoritative quantities.
