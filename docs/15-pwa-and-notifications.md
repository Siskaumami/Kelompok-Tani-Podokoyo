# PWA and notifications

The production build serves a web manifest, 192/512 icons and a separate maskable icon. Standalone launch opens `/dashboard`. Browser installation uses the browser's install/Add to Home Screen action; HTTPS is required outside localhost. Web Push availability varies by OS/browser, including installed-app requirements on some iOS configurations.

The service worker caches only app icons, an explicit offline notice and same-origin hashed static assets. Navigation remains network-first and falls back to the offline notice, not a cached authenticated dashboard. `/api/` requests and all non-GET requests bypass interception. There is no Background Sync listener, offline write queue, deferred sync, automatic critical replay, local database or cached private API response.

A sale day has one organization/date acknowledgement: COMPLETED or NO_SALES. This is a reminder acknowledgement, not a financial close. A later sale changes NO_SALES to COMPLETED and writes audit. The default business timezone is Asia/Jakarta and default reminder time 19:00; Owner may configure both.

The in-app reminder reads real organization/date/confirmation state even if push/email are unavailable. A scheduled job creates a unique daily reminder only after its local clock threshold and only when unconfirmed. It checks confirmation again immediately before each external send. A confirmation stops subsequent sends; an already in-flight provider request can still arrive.

Push registration requires explicit browser permission and actual VAPID configuration. A subscription is stored with the authenticated user. Supported push hostnames are constrained against SSRF. To keep retries unambiguous, V1 sends to one registered endpoint per user/day; a future multi-device design should track per-subscription delivery. Current UI disables all subscriptions for the account on unsubscribe.

Brevo email fallback is opt-in per organization. Missing provider configuration does not create fake successful delivery. Provider acceptance marks SENT; it is not proof of user receipt. Failures record a sanitized error and up to three attempts separated by at least 15 minutes. Expired push endpoints are removed. Organization locking prevents two job runners from concurrently sending the same delivery, but a crash after external acceptance and before database commit can still cause a bounded duplicate; exactly-once external delivery is not promised.

Background work runs every minute while the Node process is alive. `BACKGROUND_WORKER_ENABLED=false` requires an external scheduler calling `npm run jobs` every minute. `REMINDER_WORKER_ENABLED` controls reminder work inside the in-process runner; password-reset queue processing is independent. The CLI jobs command processes both. Paused/sleeping hosting cannot guarantee exact reminder time.
