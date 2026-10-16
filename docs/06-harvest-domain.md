# Harvest domain

The operator enters a business date, optional farmer, total grams, Grade A, Grade B, reject/loss and notes. UI accepts kg and converts exactly. Every draft must satisfy A+B+reject ≤ total. Unclassified weight is displayed rather than fabricated into a grade.

`POST /harvests` creates DRAFT; `PUT /harvests/:id` edits only DRAFT. `POST /harvests/:id/finalize` requires equality, creates two grade movements, changes status/finalization timestamp and appends audit within the idempotent organization transaction. Even a zero grade has an explanatory zero movement. Reject/loss never enters saleable stock.

Finalized quantities and farmer/date cannot be rewritten. `POST /harvests/:id/void` requires a reason and FINALIZED status. It reverses original grade movements. If either grade is already consumed/sold and stock would go negative, the cancellation fails entirely. The user must reconcile the actual downstream events before attempting a reversal, or use a legitimate physical count adjustment rather than inventing a past harvest.

The original record becomes VOIDED and stays visible. A corrected replacement is a new harvest with a note referencing the original. Reversal and replacement are deliberately two explicit actions; do not promise an automatic atomic replacement that the API does not implement.

Reducing Grade B may make existing soft plans infeasible. Those open plans are marked NEEDS_REVIEW, cease reserving capacity and receive audit entries. No physical number is distorted to protect a plan. Reports do not count harvest as revenue; revenue is derived from sales snapshots.

Relevant code: `modules/harvest/service.ts`; DB harvest checks and immutable-header guard; domain tests for partial drafts, equality, movement quantities, double finalization and reversal.
