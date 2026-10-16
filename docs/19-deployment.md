# Deployment and real provider configuration

## Runtime layout

Deploy one Node.js process/container behind HTTPS. It serves `/api/v1` and the Vite production files from `dist/web`. Keep browser and API on one origin. No browser database access, Redis, broker, Kubernetes, marketplace service, or separate frontend business engine is required.

Node 22.12+ or 24+ is required. `npm ci && npm run build` creates web, server and compiled administrative tools. Run `npm start`. The Dockerfile uses Node 24, a build stage and a nonroot runtime stage. Pass production secrets at runtime, not build arguments. `APP_URL` must be the exact HTTPS origin without path/query/credentials. Configure TRUST_PROXY_HOPS to the exact trusted hop count; do not blindly set trust proxy to all clients.

For local inspection, use `npm run dev` with APP_URL=http://localhost:5173. For a local production build without TLS, use NODE_ENV=development and APP_URL=http://localhost:3000. A real production deployment requires HTTPS and Secure cookies.

## Database

Create a Neon PostgreSQL database. Use its pooled connection string for DATABASE_URL, validated TLS (`sslmode=verify-full` recommended), and a direct migration connection for DATABASE_MIGRATION_URL. Do not disable certificate verification to make deployment appear successful. PostgreSQL must support normal transactions, row locks, triggers, constraints and views.

Run migrations deliberately before application rollout: `npm run db:migrate` from a full checkout, or `npm run db:migrate:prod` from the build/container. Then bootstrap/provision real accounts as documented. Migrations create schema only. The provisioner creates the actual organization/Owner and zero-balance structural raw items; no business transactions are seeded.

Use a database owner only for migrations. Grant the runtime role CONNECT/USAGE and SELECT/INSERT/UPDATE/DELETE on required application tables plus SELECT on the economics-history view. The runtime role must not own objects, create schemas, disable triggers, have superuser/BYPASSRLS, or alter role definitions. Apply grants after migrations. Review each new table's privileges in migrations. Composite FKs and service scoping provide isolation; PostgreSQL row-level security is not enabled in V1.

Set managed backups/PITR and test a restore into a separate database. Retain movement, snapshot, audit and idempotency history together. `npm run inventory:verify:prod` is a read-only ledger/cache health check. Never repair drift by direct overwriting.

## Brevo and reset processing

Configure BREVO_API_KEY, EMAIL_FROM (verified sender), EMAIL_FROM_NAME. Use the real transactional email API. Requests timeout after ten seconds and require provider messageId. Invitations commit only after provider acceptance; no credentials means 503 and no claimed delivery.

Password-reset public requests are durably queued to prevent account enumeration through provider timing/failure. The worker resolves the account, creates a hashed one-time token and sends its fragment link via Brevo. Tokens expire after 30 minutes. Pending/failed queue records are operationally inspectable in `password_reset_requests`; they contain email and sanitized state, never plaintext tokens. Up to three attempts are separated by at least 15 minutes; records expire after 30 days. Ensure the worker runs or reset emails will remain queued. Track FAILED records/old PROCESSING records, not just server uptime.

## Cloudflare R2

Create a private bucket. Configure account ID, bucket name and scoped read/write credentials. Do not enable public bucket access or a public custom domain. Uploads are server-proxied, signature-checked, decoded with a pixel limit and reencoded WebP. Clients receive only record IDs; keys/credentials are server-side. Authorized access uses a signed five-minute GET. Browser images use redirects to that signed URL. Do not log signed URLs.

A provider success followed by a database failure can leave an unreferenced object if cleanup also fails. The uploader attempts deletion when its local record/audit fails; an outer commit failure may still orphan an object. Periodically compare object keys against file metadata and references before retention cleanup. Never delete files merely because they are unpublished; unpublished files may be used in a draft. Removed image associations do not automatically delete objects.

## Web Push and background work

Generate VAPID keys using `npx web-push generate-vapid-keys`. Configure public/private key and VAPID_SUBJECT (mailto or HTTPS contact). The public key is intentionally given to authenticated clients; the private key never is. Users explicitly opt in; supported providers are hostname-constrained. Missing configuration does not produce delivery success.

The in-process worker runs every minute when BACKGROUND_WORKER_ENABLED=true. It processes password-reset requests, then sales reminders when REMINDER_WORKER_ENABLED=true. For hosts that suspend processes or multiple job workers, run an external scheduler at least every minute using `npm run jobs:prod`; disable the in-process worker if desired. Database locks/claim states coordinate runners. CLI jobs process both queues; do not schedule only reminders while leaving password reset unprocessed.

## Edge, observability and rollout

Terminate TLS at a trusted reverse proxy/CDN. Apply WAF, request limits and upload body limits; the application is not DDoS-proof. Static `/assets/` files are immutable-cacheable; API and dashboard HTML must never be CDN-cached. Preserve Origin/CSRF headers and Set-Cookie. GET `/api/v1/health` returns ready only if the database answers. It does not validate Brevo/R2/VAPID credentials.

Monitor sanitized request errors, rate-limit spikes, provider failure counts and oldest pending reset requests. Provision external uptime/backups/error collection as appropriate. Do not log request bodies or token-bearing email text. On rollout, run migrations, checks, seed no data, configure the public slug, test real Owner login, publish intentional content, then test one actual authorized email/upload/push. A full browser/real-provider acceptance pass is required in the target environment; credentials are not in the ZIP.
