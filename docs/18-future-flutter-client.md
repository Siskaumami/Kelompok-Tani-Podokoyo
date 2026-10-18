# Flutter mobile client

Flutter is implemented in `apps/mobile` as a native Android/iOS client for the existing ERP backend. React remains the web client. Inventory, planning, physical production, pricing/HPP snapshots, reporting, RBAC, idempotency and other authoritative business rules stay in the backend over the same PostgreSQL database.

The stable boundary is `/api/v1`. JSON BIGINT quantities/money are decimal strings, dates are ISO calendar dates, timestamps are ISO UTC, statuses are enumerations and errors have code/message/request_id. The mobile client must preserve these representations, use explicit domain actions and retain idempotency keys across uncertain response handling. Do not calculate authoritative stock, HPP, permissions or reports exclusively in Dart.

## Mobile transport and authentication

The web transport uses an HttpOnly cookie and in-memory CSRF. Flutter uses the same server-managed session semantics through its HTTP adapter, stores required opaque session material in platform secure storage, and keeps CSRF state transient. Mobile transport must resolve authorization into the same trusted Actor and backend permission checks; it must not fork business services or weaken web security.

Organization is always derived from verified identity. A mobile request must not gain tenant access by setting `org_id`. Public endpoints remain intentionally shaped DTOs. File upload remains validated server-side; the app must never receive unconstrained Filebase credentials. Signed Filebase image URLs are fetched without forwarding application cookies/CSRF to object storage.

## Runtime behavior

The current mobile client mirrors the ERP module set and uses Riverpod, GoRouter and Dio. It does not contain a separate database/business engine and does not queue transactional writes offline. Retry of uncertain mutations must preserve the original idempotency key and payload; automatic mutation replay remains forbidden.

Android has been exercised locally on an emulator. iOS project files exist, but build/signing still require macOS/Xcode and must be validated separately. App Links/Universal Links are not yet configured for production, so direct invite/reset handoff from email to the native app is still a deployment task. Native push FCM/APNs is also not implemented by the current backend.

A marketplace importer must call the same sale service with equivalent snapshots, channel, external reference and idempotency contract. Marketplace adapters are not the Sale core. Any future offline transactional capability requires a separate architecture review: conflicts, physical overselling and financial duplicate risks are not solved merely by introducing a sync queue. Offline transactions remain forbidden in this release.

Use OpenAPI input schemas and the API document as the contract reference, then add contract/regression tests when transport behavior changes. No React component may become a required middle tier for mobile behavior, and no Flutter widget may become an authority for backend business invariants.