# Concurrency and idempotency

All organization business/master mutations use `mutate`. Order: validate input → authorize capability → begin transaction → lock organization row → recheck live actor → read idempotency key → apply domain event → append audit → save response → commit. There is no operation-level commit between stock consumption and financial/header records.

The mutex is PostgreSQL `SELECT ... FOR UPDATE` on the organization. This serializes a small group's writes, preventing sales overselling, simultaneous planning over-allocation, stale counts, duplicate versions and conflicting corrections across modules. Different organizations proceed independently. Inventory movement insertion additionally locks the organization and atomically updates an item under a protected trigger/CHECK. All new adapters must follow this lock order.

Keys are UUIDs scoped to `(org_id,actor_id,key)`. Each saved entry binds operation (including entity ID), canonical recursively sorted JSON request hash and exact JSON response. An identical retry replays the result without re-running provider/domain actions. A changed body/operation conflicts. Disabling an actor prevents access even to replayed results. Keys have no automatic expiry in V1; deleting them casually would reopen duplicate financial writes. Review archival together with transaction-history retention.

The web form creates its key when opened, rotates it on a definitive editable change, and retains the exact payload/key after an uncertain network response. It disables edits and offers a manual retry. Mutations have no automatic retry. Reload/navigation loses the in-memory pending form; operators must inspect server records before submitting a new operation. This is intentionally not an offline persistence queue.

Opname compares revision, not just balance, inside the same mutex. Unique active-count and one-batch-per-plan indexes provide independent structural defenses. SQLSTATE serialization/deadlock/lock timeout errors become CONCURRENT_CHANGE, never raw SQL/stack text.

Password operations use user-before-reset-token locking consistently to avoid inversion between change/reset/email issuance. Reminder provider calls are bounded under an organization transaction per user/channel, preventing simultaneous jobs from both sending the same pending delivery. Provider acceptance and transaction commit cannot be made atomically across external networks; limited duplicate notification/email possibilities are documented, unlike financial domain writes which are fully atomic in PostgreSQL.
