# ADR 012: Empty-first and real integrations

Status: Accepted for V1.

## Decision

No runtime demo users/business seeds/mock provider success. Missing integrations return explicit configuration state/errors.

## Rationale

The delivered codebase must need no mock cleanup before real use.

## Consequences and change conditions

Fixtures remain isolated under tests; no development shortcut can pretend Brevo/Filebase/push accepted work.