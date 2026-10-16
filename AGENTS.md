# Repository instructions for future agents and engineers

Read README.md, docs/02-domain-model.md, docs/03-system-architecture.md,
docs/04-database-design.md, docs/21-ai-development-rules.md and the affected
module documents/ADRs before changing this project.

> BEFORE APPLYING ANY CHANGE, IDENTIFY WHICH DOMAINS, DATABASE INVARIANTS, API CONTRACTS, REPORTS, SECURITY BOUNDARIES, AND CLIENTS ARE AFFECTED. A CHANGE IS NOT COMPLETE UNTIL ITS SYSTEM-WIDE IMPACT HAS BEEN REVIEWED.

Preserve event-ledger inventory, protected balance/revision triggers, historical
sale/economics snapshots, physical variance, planning versus consumption,
organization-first transaction locks, actor-bound idempotency, backend policy,
public DTO/publication boundaries, and audit. Never implement offline business
writes, fake runtime records, mocked provider success or marketplace API sync
as a convenience. Test fixtures stay in isolated tests. Do not edit already
applied migrations. See docs/25-change-impact-checklist.md for change review.

Use `npm run typecheck`, `npm run lint`, relevant tests and `npm run build`.
TEST_DATABASE_URL must select a disposable database ending in `_test` to run
native PostgreSQL contention tests. Update OpenAPI/docs for contract changes.
No credentials belong in source, browser bundles, audit, or logs.
