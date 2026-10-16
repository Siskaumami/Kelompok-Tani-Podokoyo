# Stock opname

The operational concepts are system stock, counted physical stock, difference, and reason. The interface avoids exposing ledger mutation mechanics.

Starting a check snapshots the item's current balance and **revision**, creating OPEN status. A partial unique index forbids another open count for the same organization/item. Operators count physical goods outside the application. Completing submits physical quantity, a structured reason and optional notes; OTHER requires explanatory notes.

Completion reacquires the organization lock and compares current item revision with the baseline revision. Any intervening movement makes the baseline stale, even if its quantity later returned to the starting balance. The backend returns `STALE_BASELINE` with a clear explanation and commits no adjustment.

The explicit Refresh baseline action records the latest balance/revision and audit. It requires the operator to recount/reconcile against current physical reality. Refreshing must not be silently automated: doing so would turn an old physical count into a different event.

A valid completion emits exactly physical − baseline as OPNAME_ADJUSTMENT, stores baseline/physical/difference/reason/actor/time, and marks the check COMPLETED. A zero difference still emits a zero movement, documenting that count. Cancelling an OPEN check records the reason in audit and emits no movement. There is no approval bureaucracy.

Reasons include shrinkage/damage, failed production, earlier input error, unrecorded sale/production, missing goods and other. Selecting an unrecorded-sale reason adjusts stock only: it does not fabricate revenue. The missing real sale must be entered carefully without double-reducing stock; inspect and reverse/replace the physical adjustment as a new deliberate reconciliation if needed. Do not disguise lost revenue as an automatic accounting entry.

A lower Grade B physical quantity may mark open plans NEEDS_REVIEW. V1 reports do not automatically financially value stock differences. This limitation is visible in report notes and trade-offs.
