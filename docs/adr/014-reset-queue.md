# ADR 014: Uniform durable password-reset request acceptance

Status: Accepted for V1.

## Decision

Queue public requests independently of account lookup; worker later resolves account and sends a real token email.

## Rationale

Synchronous provider latency or failures otherwise reveal whether an email has an account.

## Consequences and change conditions

Worker/cron is a required operational dependency; 202 means queued, never delivered. No raw token is persisted in the queue.
