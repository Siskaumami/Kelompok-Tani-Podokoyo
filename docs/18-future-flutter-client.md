# Future Flutter client

Flutter is not implemented in V1. React is an API client; core inventory, planning, physical production, pricing/HPP snapshots, reporting, RBAC and idempotency are backend services over the same PostgreSQL database.

The stable boundary is `/api/v1`. JSON BIGINT quantities/money are decimal strings, dates are ISO calendar dates, timestamps are ISO UTC, statuses are enumerations and errors have code/message/request_id. A future client must preserve these representations, use explicit domain actions and retain idempotency keys across uncertain response handling. Do not calculate authoritative stock or HPP exclusively in Dart.

V1 web transport uses an HttpOnly cookie and in-memory CSRF. A native application may start with a secure cookie jar and required headers, then add an intentionally designed mobile session/token adapter: short-lived access credentials, rotation/revocation and platform secure storage. Native auth changes must resolve authorization into the same trusted Actor and `mutate` permission checks, not fork business services or weaken web CSRF.

Organization is always derived from verified identity. A mobile request must not gain tenant access by setting org_id. Public endpoints remain intentionally shaped DTOs. File upload remains validated server-side; do not grant the app unconstrained R2 credentials.

A future marketplace importer must call the same sale service with equivalent snapshots, channel, external reference and idempotency contract. Marketplace adapters are not the Sale core. A future offline client requires a separate architecture review: conflicts, physical overselling and financial duplicate risks are not solved merely by introducing a sync queue. Offline transactions remain forbidden in this release.

Use OpenAPI input schemas and the API document as the client contract, then add contract tests for each new transport. No React component should become a required middle tier for mobile behavior.
