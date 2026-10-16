# ADR 006: Plans are not consumption; physical variance is legitimate

Status: Accepted for V1.

## Decision

Plans reserve only planning capacity. Actual batches consume actual input and create actual output; theory is informational. Infeasible open plans become NEEDS_REVIEW.

## Rationale

Physical reality takes priority over recipes or plans; operators should not distort weights.

## Consequences and change conditions

Downstream count/reversal changes must reassess plans, without inventing or deleting physical events.
