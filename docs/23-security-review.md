# Completed security review

Review date: 2026-10-16 (Asia/Jakarta). Scope: application/source/database constraints, request-level tests and dependency audit. This is a project implementation review; real provider/browser/deployment configuration has a separate acceptance boundary.

> Current-state addendum (2026-10-19): this security review is a historical 2026-10-16 snapshot. The repository later added the Flutter mobile client and migrated object storage from Cloudflare R2 to Filebase. R2-specific wording below describes the reviewed snapshot and must not be read as current provider configuration. Current release acceptance must verify Filebase, mobile secure storage/transport, device behavior, and store signing separately.

| Area | Controls and review outcome |
| --- | --- |
| Passwords / login | Argon2id 64 MiB, three passes, 12–128 new-password policy; unknown-user dummy verification; durable IP/email throttles. Real Argon2 login/logout/reset paths tested. |
| Sessions | Opaque random 256-bit tokens, hashed storage, production host-only Secure/HttpOnly cookie, Lax SameSite, hard/idle expiry, active-user lookup and revocation. Compiled production-mode smoke verifies cookie attributes and post-logout denial. |
| CSRF / cross-origin | Exact Origin on all unsafe API routes; session-derived CSRF bound to stored hash on private unsafe routes. Missing Origin/CSRF tests return 403. No wildcard CORS. |
| Authorization / roles | Central backend permission gate; live actor recheck in transaction. Only Owner manages Admin/settings. Role fields rejected and platform account is CLI-only. HTTP permission/escalation tests pass. |
| Tenant isolation | Session-derived organization scope on private reads/actions; composite FKs for relationships. Cross-organization entity read/attachment tests fail safely. No normal org_id override accepted. |
| SQL injection / validation | Drizzle SQL parameters, strict runtime Zod schemas, UUID/date/integer bounds, explicit domain validation and DB constraints. Invalid references/identifier injection receive sanitized errors. |
| History / concurrency | Organization-first locks, protected ledger cache/revision, immutable movement/version/line/audit rows, guarded finalized headers, source existence checks, durable actor-bound idempotency. Native race tests pass. |
| Public data | Deliberate public projections, published/unarchived filters and file association checks. Exact DTO keys exclude HPP/inventory/security fields; draft image ID is denied. |
| Reset / invitation tokens | Cryptographically random, SHA-256 hashes, expiry, one-time consumption, fragment links. Reset invalidates sessions and other reset tokens. Active Owner required for Admin invitation acceptance. No token values appear in audit/logs. |
| Account enumeration | Forgot password now uniformly queues syntactically valid requests before account lookup. Public response says queued, not sent. Missing email configuration fails consistently. Queue/absence of fake SENT state tested. |
| XSS / URLs | React text rendering; no dangerous HTML injection. CSP self scripts, no objects/frames, no-referrer. Commerce URLs HTTPS/domain constrained; uploaded executable/SVG content rejected. |
| File upload / signed access | Auth+CSRF before parsing; one multipart part/file, max 5 MiB; detected MIME, 25-million-pixel decode limit, WebP reencoding/metadata stripping, random private keys. Publication/scoped session checks before five-minute signed access. |
| Push SSRF / privacy | HTTPS-only constrained Google/Mozilla/Apple/Microsoft providers, no embedded credentials/custom ports. Generic reminder payload has no financial/stock data. No delivery success without actual provider acceptance. |
| Rate / request limits | In-process general limiter, durable account/IP attempts, 256 KiB JSON and 5 MiB file caps. Deployment WAF/CDN/proxy limits remain necessary. Exact trusted hop count is configuration. |
| Error / secret leakage | Human error mapping, request IDs, no public SQL/stack or logged bodies/tokens. Frontend bundle scan found no database URL, Brevo/R2/private VAPID/bootstrap/password-hash identifiers. Environment example has no real secret. |
| Offline / caches | API no-store; service worker never intercepts writes or caches APIs/dashboard HTML. No localStorage authentication secrets, Background Sync or automatic write replay. |
| Dependencies | Audit initially found vulnerable Sharp and Vitest/transitive tooling. Sharp upgraded to patched 0.35.5+, Vitest to 5.0.5+, esbuild override 0.28.2+. Final `npm audit` reports **0 vulnerabilities** across production and development dependency sets. Lockfile included; builds/tests validated after updates. |

## Corrections made during review

The security-relevant fixes were queueing public reset requests to remove account-existence timing/failure leakage; consistent password lock ordering; session CSRF comparison against stored hash; strict disallowance of ambiguous localized numeric input; protection of event headers/source associations in the database; and patched dependency versions. Error details render correctly for both validation arrays and stock-availability objects, preventing a failed stock save from crashing its form.

## Deployment acceptance remaining

The ZIP contains no production secrets. Verify real Neon TLS/least-privilege roles, HTTPS reverse proxy/hop count, WAF/body limits, private R2 bucket and object access, verified Brevo sender, VAPID/device support, worker/cron uptime, pending/failed queue monitoring and backup restoration in the actual environment. Configuration-present badges do not assert valid external credentials.

Native browser visual/accessibility/PWA install and live external provider delivery were not tested here. Already-issued R2 bearer URLs remain usable for five minutes after unpublication. An in-flight notification can arrive after confirmation; bounded duplicate external delivery after a crash is possible. The runtime DB role must not own/alter tables or disable triggers. These boundaries are documented; no unresolved known critical application finding is being masked by a fake success path.