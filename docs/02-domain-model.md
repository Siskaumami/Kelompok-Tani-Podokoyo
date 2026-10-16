# Domain model

| Aggregate | Purpose and invariant |
| --- | --- |
| Organization | Scope, public profile, business timezone, reminder settings, Grade A rates |
| User/session/token | One organization per normal user; live authorization; opaque sessions; one-time hashed tokens |
| Farmer | Editable profile; independent draft/public publication; soft archive |
| Product/economics version | Editable descriptive master plus immutable full cost/price/material versions |
| Inventory item/movement | Raw grams or finished units; nonnegative protected balance and revision; append-only causal events |
| Harvest | Partial draft → balanced finalized; explicit finalization/void; no retrospective rewrite |
| Production plan | Soft planning reservation only; open/needs review/completed/cancelled |
| Production batch | Actual Grade B consumption and actual output; theoretical/cost/name snapshots; explicit reversal |
| Sale/line | Channel-neutral transaction with immutable line snapshots and historical gross/HPP totals |
| Stock opname | One active count per item; baseline quantity AND revision; physical result and causal adjustment |
| Daily confirmation | Organization/date reminder acknowledgement, not an accounting period close |
| Reminder/delivery/subscription | In-app state and actual provider acceptance with bounded retry |
| Password reset request | Uniform durable public queue; worker checks account and issues hashed token only when processing |
| Audit/idempotency | Transactional explanation of actions and replay result bound to actor/operation/input |

Raw items use `GRADE_A` or `GRADE_B` with no product ID. `FINISHED` items require a product. Each product has exactly one inventory item created in the same transaction. The provisioner creates only two structural raw items, never starting quantities.

A business date is an ISO calendar date. Timestamps are `timestamptz`. Business dates are deliberately separate from database commit time: delayed entry is valid. An economics version is the one selected when the transaction is recorded; a sale price override records the actual deal. Backdating does not silently reconstruct an unrecorded cost history.

Inventory events identify organization, item, signed delta, actor, movement type, source type/id and time. A database source-validation trigger checks the source exists in the same organization. Critical source headers cannot be deleted. Audit captures before/after/reason without credentials or token material.

Normal transitions are explicit domain actions rather than generic entity CRUD. No public endpoint can invoke internal accounting operations. Domain services accept a transaction and trusted Actor, independent of React or Express.
