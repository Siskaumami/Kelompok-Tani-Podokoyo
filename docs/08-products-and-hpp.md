# Products, prices and HPP

The product master contains SKU, name, description, one primary image, publication state and external commerce URLs. Each product has an inventory item. An archive unpublishes the product and cancels its active planning allocations while preserving inventory, versions and transactions. Remaining archived stock can still be sold manually; it cannot be chosen for new production/plans.

Economics are immutable complete versions: grams of potato per finished unit, material Rupiah, packaging Rupiah, production Rupiah, other Rupiah, selling price, reason, actor and timestamp. HPP is a generated sum of the four integer cost components. Material grams and material Rupiah are distinct quantities.

Every economics update appends a new version. `product_economics_history` uses `LEAD(created_at)` to expose the next version's effective-until time without rewriting old versions. Version order is authoritative if timestamps tie. The current version is the highest version number.

A production batch snapshots theoretical material and HPP from the version chosen at entry. A sale snapshots its unit price, unit HPP, name, quantity, line gross/HPP, and source version ID. Reports sum stored transaction totals. Renaming a product or changing current costs cannot change an old transaction's economics.

V1 deliberately uses simplified current-version costing at entry, not weighted-average/FIFO inventory layers. A backdated sale can override actual unit selling price; its HPP uses the version selected at entry. There is no retroactive automatic cost lookup. Grade A uses the organization's current per-kg price/HPP and snapshots both in every raw sale line; settings changes are audited.

Public product DTOs contain selling price and purchase links but never HPP, raw costs, inventory, version IDs or audit. HTTPS URLs are restricted to the supported marketplace/WhatsApp domains; executable or unrelated schemes are rejected. No marketplace API is invoked.
