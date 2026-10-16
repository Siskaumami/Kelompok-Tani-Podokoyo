# Inventory ledger

`inventory_movements` explains every stock change. `inventory_items.balance` is a protected cache, not the sole source of truth. `revision` advances for every movement, including a zero-difference completed count. This catches stale checks even if intervening transactions restore the original quantity.

| Event | Item | Delta |
| --- | --- | --- |
| Harvest finalization | Grade A / B | Classified grams, separately |
| Grade A sale | Grade A | Negative sold grams |
| Actual production | Grade B | Negative actual grams |
| Actual production | Finished | Positive actual units |
| Finished sale | Finished | Negative sold units |
| Completed opname | Counted item | Physical minus baseline |
| Audited void | Original items | Exact opposite of original event deltas |

The `move` service checks availability and returns a useful message including available quantity. The database trigger performs the balance increment and revision change; the nonnegative CHECK is the final guard. A failure rolls back the whole business operation, audit and idempotency record. Do not bypass `mutate` or issue writes outside its transaction in a new integration.

All organization mutations acquire the same organization row lock first. At village-group scale this deliberately favors correctness and a simple lock order over maximizing per-item throughput. Different organizations do not share that lock. Direct movement insertion also locks the organization before updating an item.

`npm run inventory:verify` compares every cache with `SUM(delta)`. It is read-only; it does not overwrite differences. If drift is ever found, investigate migrations, privileged writes and deployment roles before planning an audited repair. Back up first. Normal users have no edit-stock-number endpoint.

Raw grams and finished units are separate dimensions. A Grade A price is per kg; calculation uses `(grams * rate + 500) / 1000` in BigInt, rounded half-up to Rupiah. Grade B planning never emits a physical movement.
