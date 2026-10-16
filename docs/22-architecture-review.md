# Completed architecture review

Review date: 2026-10-16 (Asia/Jakarta). Scope: final source, migration, automated domain/HTTP tests, native PostgreSQL pool contention, compiled application/admin-tool smoke and PDF rendering. No runtime demo setup is required.

## System-wide acceptance findings

| Question | Result and evidence |
| --- | --- |
| Can concurrent submissions oversell? | Native PostgreSQL pool test races separate actors; one sale commits and the other fails. Organization lock, balance trigger/CHECK and rollback protect every item. |
| Can duplicate retries create a second sale? | Sequential replay and simultaneous native identical-key tests return one sale and one stock reduction. Different-body key reuse conflicts. |
| Can planning consume Grade B? | Plan services never call movement insertion; tests prove balance unchanged and total planning capacity enforced. |
| Can physical production differ from theory? | Actual/theoretical inputs are distinct snapshots. Test produces 480 units with 10,000 g actual versus 9,600 g theoretical. Both movements are verified. |
| Can a physical count silently replace newer stock? | Quantity plus revision baseline and a unique active-count index. Stale test changes stock and restores its old number; completion still fails until explicit refresh/recount. |
| Can price/HPP changes restate reports? | Immutable versions and line snapshots. Tests update both price and cost, then verify original gross/HPP/profit and PDF generation. |
| Can important history disappear? | No transaction delete routes; immutable movements/versions/lines/audit, guarded event headers and source validation. Reversals retain original events and reasons. |
| Can infeasible plans block recording actual reality? | Actual production/count completes if physical stock rules hold; excess open plans become audited NEEDS_REVIEW rather than forcing a theoretical input. |
| Can report and PDF diverge? | Both use `buildReport`; renderer consumes the returned object. A persisted 20-sale QA export matched expected totals across four rendered pages. |
| Can organizations cross-reference records? | Scoped reads plus composite FKs. Service/constraint tests reject foreign-organization product access/plan relationships. |
| Can Admin invite/escalate role? | Backend capability gate and strict schemas. HTTP tests refuse Admin invitation and role injection. Normal UI exposes Owner/Admin only. |
| Can public API leak HPP, inventory or drafts? | Named projections and explicit DTO mapping; exact-key and publication/image tests. |
| Can frontend become the authority? | React only serializes/forms/displays. Domain logic, permissions, locks, economics and reports are server services. |
| Can a future Flutter client reuse this? | Versioned REST, shared schemas/OpenAPI, trusted Actor/domain services independent of React/Express transport. |
| Can service worker queue writes or expose cached data? | Reviewed GET-only static allowlist, API bypass, network-only navigation with offline notice, no sync/write listener. |
| Can startup need fake data? | Compiled migration/provisioning smoke starts with zero farmers/products/harvests/sales/batches/movements; only actual account/org and two structural zero raw items exist. Empty public/report/PDF endpoints pass. |
| Can a missing external provider pretend success? | Missing email/R2 upload tests return configuration errors; no fake delivery IDs. Reset queue acceptance explicitly means queued, and configured sender work uses real Brevo. |
| Do administrative tools actually run from build? | Compiled migrations run twice, bootstrap refuses a second platform account, provisioning creates an actual Owner, ledger verification passes. |

## Issues discovered and corrected

1. **Test database integer transport mismatch:** PGlite initially decoded BIGINT into Number while production pg used strings. Explicit INT8/NUMERIC parsers now match production; a value beyond Number.MAX_SAFE_INTEGER is verified exactly.
2. **Overly broad immutable-header comparison:** a PostgreSQL generated net column is unavailable in a BEFORE UPDATE NEW row. The guard now excludes that derived column while preserving all actual financial fields. Voids and stale-count regression paths pass.
3. **Password-operation lock inversion:** reset, change and reset-email issuance now lock user before reset tokens, avoiding competing lock orders.
4. **Public forgot-password account enumeration:** provider latency/failure no longer depends on account existence in the HTTP response. A uniform durable request queue is processed later, with no plaintext token in queue records and no false sent assertion.
5. **Ambiguous kg input:** `1.000` is rejected; `1000` is one thousand kg and `1,250` is 1.25 kg. Exact integer conversion/display tests protect this operator-facing rule.
6. **Mixed error-details shapes:** the form now renders field-error lists only when details is an array, preserving stock-error handling when details is an availability object.
7. **Long PDF line/page flow:** measured text height, transaction-start preflight and page-number footers prevent overlaps/orphan starts in the verified long-name export. Financial calculations remain unchanged.

## Verification limits and intentional scope

Automated results: 34 tests passed with TEST_DATABASE_URL supplied, including both native contention tests; affected report tests were rerun after PDF formatting changes. Typecheck, lint and complete builds pass. Native test PostgreSQL was isolated and temporary; no production credentials or data were used.

Browser visual/touch/install/push checks were not performed because no supported browser QA capability was available. Responsive CSS, native dialogs, empty states, units, PWA assets and HTTP serving are implemented and reviewed; a target-browser pass remains required. Real Neon network/TLS, Brevo/R2 credentials and device push delivery were not available, so live acceptance is not asserted. These limits are not replaced by mocked success.

Known noncritical scope choices are documented in `24-known-tradeoffs.md`: simplified HPP, original-period void reporting, no full accounting/partial returns/FIFO, one primary image, one push endpoint/user/day and organization-level serialization. No known critical domain defect remains in the reviewed paths.
