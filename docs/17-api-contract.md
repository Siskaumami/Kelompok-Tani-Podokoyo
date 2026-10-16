# REST API contract

Machine-readable OpenAPI 3.1 is `docs/openapi.json`, generated from the shared Zod input schemas using `npm run api:generate`. It documents 62 HTTP operations. Prefix is `/api/v1`. Successful JSON is `{data: ...}`. Errors are `{error:{code,message,details?,request_id?}}`; do not parse localized message text as a machine contract.

## Representations and authentication

BIGINT quantities/money are unlocalized decimal strings; no exponent, thousands separators or localized commas. Raw quantity means grams, finished quantity means units. Monetary fields mean integer Rupiah. Grade A unit rates are per kg. ISO dates mean business dates, UTC ISO timestamps mean instants. Inputs are strict: extra fields are rejected.

Login returns public session-user fields and an in-memory CSRF token, with the opaque session in an HttpOnly cookie. `/auth/me` refreshes the CSRF value. Unsafe requests require exact `Origin: <APP_URL origin>`; private unsafe requests also require `X-CSRF-Token`. Organization mutations additionally require a UUID `Idempotency-Key`. Never send org_id or role escalation fields. JSON bodies may be `{}` for no-field actions. Upload uses one multipart `image` field, same security headers and idempotency key.

## Endpoint families

| Family | Reads | Writes/actions |
| --- | --- | --- |
| Public | `/public/site`, `/public/{slug}`, `/public/{slug}/files/{id}` | None |
| Auth | `/auth/me` | login, logout, forgot-password, reset-password, accept-invitation, change-password |
| Organization | `/organization`, `/configuration`, `/overview` | PUT `/organization/settings` (Owner), PUT `/organization/content` |
| Farmers | GET `/farmers` | POST create, PUT `/{id}`, POST `/{id}/archive` |
| Products | GET `/products`, `/{id}/history` | POST create, PUT metadata, POST economics version, POST archive |
| Harvest | GET `/harvests` | POST draft, PUT draft, POST `/{id}/finalize`, POST `/{id}/void` |
| Inventory | GET `/inventory`, `/{id}/movements` | Changes only through domain events |
| Plans | GET `/production/plans` | POST create, PUT `/{id}`, POST `/{id}/cancel` |
| Production | GET `/production/batches` | POST completed batch, POST `/{id}/void` |
| Sales | GET `/sales`, `/sales/{id}` | POST completed sale, POST `/{id}/void`, POST `/sales-day/confirm` |
| Stock opname | GET `/opnames` | POST start, POST `/{id}/refresh`, `/{id}/complete`, `/{id}/cancel` |
| Reports | GET `/reports`, `/reports/pdf` | None |
| Users | GET `/users`, `/users/invitations` (Owner) | POST `/users/invitations`, PUT `/users/{id}/active` (Owner) |
| Notifications | GET `/notifications` | POST/DELETE `/notifications/push` |
| Files | GET `/files/{id}` | POST `/files` |
| Audit | GET `/audit` | No edit/delete API |
| Health | GET `/health` | None |

Each family is implemented in its domain module; HTTP adapters live in `app.ts`. Product metadata updates do not update economics. Creating a product includes nested `economics`. Creating a sale includes 1–50 `items`; line item is item_id, quantity, optional unit_price_rp. Production accepts optional plan_id. An opname completion accepts physical_quantity, structured reason and notes.

## Pagination and reports

Harvest, plans, batches, sales, opnames, audit and item movements use `limit` 1–100 (default 30), `offset` 0–1,000,000. Response is `{items,next_offset}`; null means no next page. Ordering is deterministic by dates/timestamps/ID. Masters are unpaginated for village scale; they should be paginated if installations grow significantly.

Reports accept optional `from` and `to`; both default to today in business timezone. Boundaries are inclusive. Maximum inclusive interval is 367 days. A large period fails explicitly rather than truncating totals. PDFs use the identical report result and add generated-by identity.

## Stable error codes

AUTH_REQUIRED/INVALID_CREDENTIALS → authenticate; FORBIDDEN/ORG_ACCESS_REQUIRED → permission; VALIDATION/INVALID_REFERENCE → fix input; INSUFFICIENT_STOCK → refresh availability; HARVEST_BALANCE → complete grading; PLAN_EXCEEDS_STOCK → reduce/release plan; STALE_BASELINE → refresh and recount; IDEMPOTENCY_CONFLICT → do not reuse a key with changed input; CONCURRENT_CHANGE → refetch and retry deliberately; RATE_LIMIT → wait; EMAIL_NOT_CONFIGURED/STORAGE_NOT_CONFIGURED/PUSH_NOT_CONFIGURED/DATABASE_NOT_CONFIGURED → configure the actual provider.

Forgot password returns **202 queued**, not a successful-delivery assertion. Invitation success says ACCEPTED_BY_PROVIDER only after actual Brevo acceptance. Image access returns a short-lived 302 signed R2 URL. API responses use no-store and do not expose SQL/stack traces. Swagger UI is not hosted publicly; use the local OpenAPI file with engineering tools.
