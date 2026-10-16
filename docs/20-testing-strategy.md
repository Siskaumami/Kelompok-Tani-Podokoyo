# Testing strategy

Tests focus on business loss/security invariants rather than maximizing counts. `tests/` contains isolated fixture data and test-only account hashes. No runtime or migration imports it. There are no business seed files.

`npm test` runs Vitest with actual PostgreSQL semantics through PGlite, a PostgreSQL WASM build; the same migration including PL/pgSQL triggers is executed. INT8/NUMERIC parsers explicitly preserve decimal strings, matching node-postgres, so values beyond JavaScript safe integer remain exact. This is not a mock business API or production database substitute.

Coverage includes draft/final harvest balance, correct movements, append-only/protected caches, nonnegative stock, void history, planning without consumption, over-allocation, actual/theoretical variance, finished output, infeasible-plan review, historical price/HPP, report/PDF consistency, duplicate keys, overselling, Grade A rounding, stale count revision and explicit refresh, reason validation, authorization, public DTOs/drafts, composite tenant ownership, reset token consumption/session revocation, daily confirmations and absence of fake provider delivery. HTTP tests exercise sessions/cookies, Origin/CSRF, privilege injection, input error sanitization, private image boundaries, upload format checks and missing provider configuration.

## Native PostgreSQL contention

`tests/postgres.test.ts` opens a normal node-postgres pool against TEST_DATABASE_URL and a private random schema. It uses separate pool connections to race two overselling requests and two identical idempotent submissions. The URL database name must end in `_test`; schema creation/drop is confined to that dedicated database. It does not use the application's production DATABASE_URL as a fallback.

One local option:

1. Set TEST_DB_PASSWORD securely.
2. `docker compose -f compose.test.yaml up -d`
3. Set TEST_DATABASE_URL to that PostgreSQL instance/database.
4. `npm test` (or `npm run test:postgres`).
5. Stop/remove the disposable test service after verification.

Without TEST_DATABASE_URL, native tests are explicitly skipped; that is not a claim that multi-connection contention passed. Validation evidence in the review records whether the native suite was supplied and run for this delivery.

## Other checks

`npm run typecheck`, `npm run lint`, `npm run api:generate`, `npm run build`, `npm audit`, and read-only ledger verification are available. The build includes compiled administrative tools so the production runtime need not retain dev dependencies for migration/provisioning.

No provider success is fabricated in tests that are presented as live integration verification. Real Brevo, R2 and Web Push acceptance is not claimed without credentials. Browser responsive/accessibility/install/push smoke checks must run in a supported browser in the deployment environment; source/CSS and HTTP tests are not equivalent to a visual browser pass. See the review and QA checklist.
