# Sales

The channel-neutral sale aggregate supports OFFLINE, WHATSAPP, SHOPEE and TOKOPEDIA, business date, optional external reference, notes, multiple lines, one sale-level discount, manual marketplace fee, actor and status. There is no checkout or payment integration. External reference is descriptive and not unique: different channels can legitimately reuse references. Use idempotency, not order-reference guessing, to prevent retry duplicates.

Only Grade A and finished goods are saleable. Grade A quantity is grams and rates are per kg; finished quantity is integer units. Blank/omitted price selects the current rate. Explicit price snapshots represent the actual deal. HPP always comes from the applicable current cost basis at entry. Finished names and economics-version IDs are saved alongside the snapshots.

Calculations use BigInt and stored integer totals:
* Gross = sum of rounded line gross totals.
* HPP = sum of rounded line cost totals.
* Net = gross − discount − marketplace fee.
* Estimated gross profit = net − HPP.

Discount and fee cannot be negative or together exceed gross. Profit may legitimately be negative. A listed unit price is not assumed to equal cash received. Duplicate item lines are safe: each movement is applied inside the same transaction, and insufficient aggregate stock rolls back the entire sale.

`POST /sales` locks the organization, computes snapshots on the server, writes header/lines, emits reductions and audit, reconciles daily reminder acknowledgement, and records the idempotency response. If response delivery fails, replaying the same actor/key/operation/body retrieves the original sale. A different payload with that key is rejected.

`POST /sales/:id/void` requires a reason and COMPLETED status. It restores original sold quantities, retains lines/header, marks VOIDED and writes audit. A replacement is a new explicit sale. V1 void represents a full cancellation with full stock return; partial returns and nonreturnable refunds require an intentionally designed future domain, not a casual edit of lines.

A NO_SALES confirmation changes to COMPLETED if a later valid sale is recorded for that business date. Confirmation never prevents delayed entry. Voids restate the original period; this is operational bookkeeping rather than locked-period accounting.
