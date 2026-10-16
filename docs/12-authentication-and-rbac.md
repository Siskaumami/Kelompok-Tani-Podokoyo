# Authentication and RBAC

Web sessions are random 256-bit tokens in HttpOnly cookies, Secure in production, SameSite=Lax, Path=/ and host-only. Production cookie name is `__Host-tani_session`; development uses `tani_session`. Only SHA-256 session-token hashes and CSRF hashes are stored. Session lifetime is 12 hours with a two-hour idle timeout. Each authenticated request checks current user active state, organization, expiry and idle timestamp. Business mutation rechecks actor role/active state after obtaining the organization lock.

The client retrieves a per-session CSRF token from `/auth/me` and keeps it in memory. Its server-side hash is checked indirectly through the authenticated session-derived value, using timing-safe comparison. All unsafe API methods require an exact APP_URL Origin. Private unsafe methods also require `X-CSRF-Token`. The cookie token is never in localStorage, JSON responses, or frontend bundle configuration. Login/logout and password routes use their dedicated transport adapters.

Passwords use Argon2id (64 MiB, three passes, one lane). New passwords require 12–128 characters. Login verifies a per-process random dummy hash for unknown emails, reducing fast account-discovery paths. Durable PostgreSQL rate limits cover login IP/email, forgot password IP/email, token attempts and password change; an additional in-process HTTP limiter and deployment WAF protect request volume.

| Capability | Admin | Owner | Super Admin |
| --- | --- | --- | --- |
| Normal operations / audit / public content | Yes | Yes | CLI only, no organization UI |
| Invite/deactivate/reactivate Admin | No | Yes | Provisioning tools |
| Organization operational settings | No | Yes | Provisioning tools |
| Assign Owner/Super Admin through org API | No | No | No such API |

`authorize` and `mutate` centralize policy. Frontend visibility is a convenience, not enforcement. Role fields are absent from invitation acceptance and normal mutation schemas. Extra fields are rejected. Users are not hard-deleted; deactivation revokes sessions and retains audit attribution. Owners cannot deactivate another Owner through this UI.

Invitations expire after 48 hours, are single-use, store only token hashes, and require an active Owner creator at acceptance. Only actual Brevo provider acceptance yields a successful invitation response. Reset tokens expire after 30 minutes; reset/change invalidates all account sessions and outstanding reset tokens. Token links use URL fragments, which are removed from browser history on the auth page; HTTP logs never receive the fragment.

Forgot-password uniformly accepts a durable request for any syntactically valid email, after configuration/rate-limit checks. A worker checks account existence later, preventing provider latency/outage from enumerating accounts. Responses explicitly describe queue acceptance, not delivery. Worker retries are bounded and failure state is stored. Post-change security email reports ACCEPTED_BY_PROVIDER, FAILED or NOT_CONFIGURED separately from the successful password change.
