# Release verification record

Verified for this packaged source/build on 2026-10-16:

> Current-state addendum (2026-10-19): this record describes the packaged source verified on 2026-10-16. Since then the repository added/iterated the Flutter mobile client, changed object storage to Filebase, changed web/mobile UI, and implemented Android native push through Firebase Cloud Messaging. Keep the original record as historical evidence, but do not treat its R2/browser-only statements as verification of the current tree. Run the current web/backend and Flutter checks again before release.

> Native-notification verification (2026-10-19): Flutter Android notification permission and FID registration succeeded, the authenticated FID was persisted in PostgreSQL, Firebase Admin delivered a direct test notification, and the real sales-reminder worker delivered `MOBILE_PUSH` with `sent=1, failed=0` to the Android 16 emulator. A confirmed sales day correctly suppressed reminder delivery. iOS/APNs and production physical-device/store delivery remain separate release gates.

* Node.js 24.19.0, TypeScript 5.9, Vite 7.3, Vitest 5.0.5, native PostgreSQL 18.4 and PostgreSQL WASM/PGlite test engine.
* `npm run typecheck`: passed.
* `npm run lint`: passed, max warnings zero.
* `TEST_DATABASE_URL=<isolated PostgreSQL ..._test> npm test`: **34 passed, 0 failed, 0 skipped**. Includes two actual pool-connection contention tests.
* Report-domain regression rerun after PDF layout correction: passed.
* `npm run api:generate`: 62 operations from shared runtime input schemas.
* `npm run build`: frontend, backend and compiled administrative tools passed. Upstream Zod PURE-comment annotation notices are nonblocking bundler warnings.
* `npm audit`: **0 info/low/moderate/high/critical vulnerabilities** at verification time.
* Compiled-tool smoke: migration applied then rerun safely; one-time bootstrap works/refuses repeat; provisioning creates actual isolated Owner/org; all business tables remain empty; two structural zero raw items; ledger cache verification succeeds.
* Compiled-server HTTP smoke: ready health, served frontend, empty published site, manifest/all icons, real Argon2 Owner login, production Secure/HttpOnly host cookie, zero report/PDF, logout/session revocation.
* PDF QA: export from 20 isolated persisted sale events, exact gross/net/HPP/profit, long names wrapped; page PNGs inspected; page bounds and numbering checked. Test export/fixtures are outside the deliverable and are not runtime sample data.
* Browser bundle scan: database URL, Brevo key, R2 secret, private VAPID key, bootstrap/platform passwords and password hashes absent.

Not claimed complete: production browser visual/touch/accessibility/install QA, live Neon/Brevo/Filebase credential verification, and production physical-device/store push validation. No supported browser capability or production credentials were available. Follow the deployment guide for those checks. No fake provider success substitutes for them.

## Target-browser go-live checks

- [ ] Desktop, tablet and narrow mobile: public navigation, table-to-card layout, dialog focus/keyboard, 44 px touch actions, units and empty/error states.
- [ ] Owner/Admin access with actual accounts; invite and reset from real email links; expiry and deactivation.
- [ ] Real Filebase upload and private unpublished/published image access; bucket has no public bypass.
- [ ] Install from supported HTTPS browser; offline navigation shows notice; no transactions queued.
- [ ] Explicit Web Push/native push opt-in; actual unconfirmed-day reminder; confirmed day suppresses subsequent sends; validate Android production device and iOS/APNs separately.
- [ ] Real operating walkthrough and report/PDF reconciliation; backup restoration into a separate database.