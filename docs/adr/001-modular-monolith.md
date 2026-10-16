# ADR 001: Modular monolith

Status: Accepted for V1.

## Decision

One TypeScript backend with explicit domain modules and REST adapters.

## Rationale

Village-scale delivery, transaction atomicity and maintainability outweigh speculative service isolation. No broker, Kafka, Redis or Kubernetes is required.

## Consequences and change conditions

Independent service extraction requires evidence and a replacement for cross-domain transaction guarantees.
