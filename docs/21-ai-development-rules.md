# Mandatory AI/developer change rules

> BEFORE APPLYING ANY CHANGE, IDENTIFY WHICH DOMAINS, DATABASE INVARIANTS, API CONTRACTS, REPORTS, SECURITY BOUNDARIES, AND CLIENTS ARE AFFECTED. A CHANGE IS NOT COMPLETE UNTIL ITS SYSTEM-WIDE IMPACT HAS BEEN REVIEWED.

Read the domain model, system architecture, database design, affected domain documents, ADRs and change-impact checklist before editing. Trace both upstream causes and downstream inventory/reporting/security effects. A locally plausible patch is incomplete until the whole system remains coherent.

1. Preserve causal append-only movements and their protected cached balances/revisions. Never replace stock with a mutable number API.
2. Preserve historical names, prices, cost snapshots and stored line totals. Current product values cannot recalculate old reports.
3. Preserve plans versus physical production. Actual material may differ from theory.
4. Preserve before/after/reason audit and explicit reversals; never hard-delete important history.
5. Preserve backend permissions and live organization scoping. Frontend hiding is insufficient.
6. Preserve intentionally shaped public DTOs and publication/file access checks.
7. Preserve actor/operation/input-bound idempotency, organization lock order and transaction atomicity.
8. Preserve server-owned domain logic so React and the current Flutter client use the same invariants and authority.
9. Do not add offline financial/stock writes, automatic mutation retries or deferred sync casually.
10. Do not add infrastructure complexity without actual value. A modular monolith is intentional.
11. Prefer a practical operator workflow over academic manufacturing/accounting ceremony.
12. Record physical reality; do not falsify consumption to match a recipe.
13. Add no fake/demo runtime users, farmers, products, movements, sales or reports. Fixtures belong only in isolated tests.
14. Replace no real provider boundary with mocked success. Missing credentials must remain explicit.
15. Do not add marketplace synchronization, native checkout, native push, deep-link infrastructure, or offline transactional sync without explicit scope and system-wide review.
16. Treat quantities/money as exact integer strings/BigInt. Never casually convert to Number for calculations.
17. Use additive migrations after deployment; do not edit applied checksummed SQL.

When an issue is found: identify root cause and affected domains; fix it; review overall consequences; add/update meaningful regression tests and documentation; rerun affected checks. Update OpenAPI if the contract changes. A completed change includes review evidence and honest limitations, not a claim of absolute security.