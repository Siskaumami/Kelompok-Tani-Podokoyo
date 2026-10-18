# Intentional initial bootstrap

No user or password is included in this repository. Normal startup and migrations never create login accounts. Two deliberate commands establish actual ownership.

## 1. Create the platform account once

Migrate first. Supply these environment variables securely for the single command:

| Variable | Meaning |
| --- | --- |
| BOOTSTRAP_CONFIRM | Exactly CREATE_SUPER_ADMIN |
| BOOTSTRAP_EMAIL | Actual developer/platform email |
| BOOTSTRAP_NAME | Actual platform operator name |
| BOOTSTRAP_PASSWORD | Actual password, at least 12 characters |

Run `npm run bootstrap` (or `npm run bootstrap:prod` after building). It obtains an advisory transaction lock, refuses if a SUPER_ADMIN exists, hashes with Argon2id, and stores no organization/business data. No default password exists. It does not log credentials. The account is real platform administration, not a demo user.

Prefer a secret manager or a protected terminal variable. For example in bash, `read -rs BOOTSTRAP_PASSWORD` then `export BOOTSTRAP_PASSWORD` avoids putting the password in shell command history. Do not commit a credentials file. Clear all bootstrap variables immediately after the command.

## 2. Provision an actual group and Owner

Supply PROVISION_CONFIRM=CREATE_ORGANIZATION, PLATFORM_EMAIL and PLATFORM_PASSWORD for that active SUPER_ADMIN, ORG_NAME, ORG_SLUG (lowercase letters/digits/hyphens), OWNER_EMAIL, OWNER_NAME and OWNER_PASSWORD (12+ characters). Run `npm run organization:create` or `npm run organization:create:prod`.

The provisioner authenticates the platform account, hashes the actual Owner password, creates organization/Owner and the two zero-balance structural raw inventory items in one transaction, then records platform attribution in audit. It creates no farmer, product, harvest, production, sale, stock count or inventory movement. Unique email/slug constraints make accidental duplicates fail atomically.

Set PUBLIC_ORG_SLUG to the chosen slug and clear provisioning variables from the environment. Normal service configuration must contain none of the bootstrap/platform/Owner passwords. Sign in as the actual Owner at `/login`; normal UX exposes only Owner and Admin. SUPER_ADMIN has no ordinary organization-session login.

## 3. Invite Admin users normally

Configure real Brevo credentials and verified sender. Owner opens Pengguna → Undang Admin and supplies the actual person's email/name. Successful response requires actual provider acceptance. Recipient receives a 48-hour fragment-token link and chooses a password; the backend always assigns ADMIN. Admin cannot invite another Admin, assign roles or modify operational settings.

Deactivation revokes sessions and preserves audit. Owner may reactivate the same Admin; password recovery is available through the email workflow. Owner transfer UI is implemented and uses the reviewed backend transfer flow: the target must be an active Admin in the same organization, the current Owner confirms with password, role changes are transactional, sessions/audit are updated, and the database still enforces one Owner. Any platform recovery procedure must preserve organization ownership and attribution rather than modifying roles through an unreviewed ordinary API.