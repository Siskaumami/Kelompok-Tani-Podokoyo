# Public and private data boundary

Public routes do not run session middleware or depend on frontend hiding. `publicData` queries the organization by slug, projects its public name/slug, published village profile, unarchived published farmers and unarchived published products. Explicit object construction returns public DTOs.

Product DTO fields are exactly ID, name, description, imageUrl, sellingPrice, shopeeUrl, tokopediaUrl and whatsappUrl. Farmer DTO is ID, name, bio and imageUrl. Village DTO is title/body/imageUrl or null. No HPP, material cost, version IDs, inventory quantity, internal notes, audit, account data or unpublished profile is returned. Organization settings and private financial reports require a session.

`/public/site` selects PUBLIC_ORG_SLUG for the installation. `/public/:slug` allows intentionally published organizations by known slug. A slug is not a private API token. Multi-organization private access still derives org_id from the user session, never that public slug.

Public image access checks whether the file is attached to currently published content in the same organization before signing Filebase access. Knowing a draft image ID does not make it public. Private image access checks the session organization. The private Filebase bucket must not have an alternate unrestricted public URL; publication checks would be meaningless otherwise. A signed URL already issued may remain valid for five minutes.

Empty public collections are normal responses. Missing site configuration is a clear 503, not a made-up village or fabricated catalogue. No business records are hardcoded in React. Static app branding and nonrecord illustrative graphics are not operational data.

Tests verify exact product DTO keys, draft exclusion, unconfigured-provider behavior, known draft-image access and cross-organization references. When adding a field, assess public sensitivity explicitly and update DTO tests/OpenAPI.