# Production planning and actual production

A plan records product, intended date and Grade B grams. OPEN plan totals may not exceed physical Grade B stock. Planned capacity is balance minus other open plans. Saving/changing a plan runs under the organization lock, preventing simultaneous over-allocation. It creates audit, not inventory movement.

Plan statuses are OPEN, COMPLETED, CANCELLED and NEEDS_REVIEW. Only OPEN reserves planning capacity. A needs-review plan can be changed/reactivated if sufficient capacity exists, cancelled, or used to record a real completed physical batch. Plans are never automatically treated as completed manufacturing.

Actual production records actual consumed grams and actual output units. The current immutable product version provides theoretical grams-per-unit and simplified HPP. Batch snapshots include that version, theoretical total, unit HPP, product name, date and actor. Actual input may differ from theory for loss, failed output, equipment retention, sampling or weighing differences. The UI displays the variance without forcing equality.

A completed batch consumes actual Grade B and creates actual finished output in one transaction. When linked to a plan, the product must match and the plan closes. A unique database index permits only one batch per plan. Production may also be entered without a plan.

Physical consumption or a count can make other plans infeasible. In that case **all remaining open plans are marked NEEDS_REVIEW** rather than arbitrarily preserving one operator's allocation. This is visible and audited; the actual batch remains correct. Operators adjust plans against the new real stock.

A reasoned void reverses the output first and input second, requiring output still available. If downstream sales already consumed output, the reversal fails atomically. A void does not reopen the original plan or silently recreate capacity reservations. Enter a new plan if appropriate. Ordinary failed production can instead be represented by actual material use/output and a legitimate later count adjustment; zero-output wastage belongs in a documented physical adjustment because V1 completed production requires positive output.

Costing is version-based simplified HPP, not FIFO batch valuation. The batch's HPP snapshot is preserved, but sale costing uses the economics version at sale entry. This explicit trade-off is in ADRs and the HPP document.
