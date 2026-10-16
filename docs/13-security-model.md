# Security model

The application uses layered controls with an explicit deployment boundary. It is HTTPS/CDN/WAF-compatible; it does not claim DDoS immunity. See the completed review for test evidence and remaining verification limits.

## HTTP and application

Helmet sets CSP, frame restrictions, no-referrer, MIME sniffing protection and production HTTPS policy. JSON bodies are limited to 256 KiB. Multipart has one file/part and a 5 MiB limit. All API responses are no-store. Static hashed assets can be cached; application HTML is not. No wildcard CORS is enabled. Unsafe requests require exact Origin, and authenticated writes additionally require session CSRF.

Zod strict schemas validate inputs at the HTTP boundary; domain functions enforce business invariants. SQL values use Drizzle parameters. Dynamic schema identifiers are confined to isolated tests/migration tooling; no user identifier is concatenated into SQL. Errors are mapped to human messages; logs contain request ID, event and sanitized error code, not query text, stack traces, credentials, tokens or complete request bodies.

React renders text safely and uses no `dangerouslySetInnerHTML`. Marketplace URLs are HTTPS and domain constrained. Public DTOs explicitly project public fields and publication state. Organization comes from a server session. Composite FKs defend cross-organization associations.

## Storage and files

R2 uses a private bucket. Server detects file signatures, accepts only JPEG/PNG/WebP, limits decoded pixels, reencodes to WebP and strips metadata. SVG, HTML and executable payloads are not accepted. Random organization-scoped keys avoid traversal and collisions. Access is authorized before issuing a five-minute signed GET. A previously issued signed URL remains usable until expiry after unpublishing; it is a bearer URL, not an instantly revocable session. Never log it or make the whole bucket public.

Push endpoints are HTTPS, no credentials/custom port, and limited to supported Google/Mozilla/Apple/Microsoft push hosts. This prevents arbitrary callback-URL SSRF. Payloads contain a generic reminder without stock or financial data. Email sender and provider secrets are server-only; calls have bounded timeouts and require actual provider message IDs.

## Database and operations

Use distinct migration/runtime roles, TLS with validated server certificates, backups and tested restore procedures. Runtime must not own tables or disable triggers. Append-only ledgers, protected balance/revision and transaction-scoped organization locks enforce domain history. Application checks remain required; direct owner/superuser SQL is not a supported operational interface.

Trust only the actual reverse proxy hop count. Configure WAF/body limits and per-origin/IP limits at the edge, monitor failed auth/provider jobs and run dependency audits. Use secret-manager injection; bootstrap variables must not remain in the service environment. Never grant the browser direct database or R2 credentials.
