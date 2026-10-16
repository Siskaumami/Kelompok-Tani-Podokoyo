# Product goals and operational UX

The product has two surfaces: a village/farmer/product website for visitors and an authenticated operational workspace. Visitors buy through external marketplace or WhatsApp links. There is no internal cart, payment gateway, marketplace API or marketplace synchronization.

The workspace reduces duplicate entry. A finalized harvest increases Grade A/B inventory; actual production consumes Grade B and creates output; a completed sale reduces its items; a physical count explains stock differences; bookkeeping reads already-entered sales. Operators do not enter those financial totals again.

New installations guide the first real entry. Public pages show publication-aware empty states. The dashboard shows a first-harvest guide until real stock-producing or sales activity exists. Products, farmers and events are never invented for presentation. A zero-period report represents a genuine empty period.

Mobile layouts replace table rows with labelled cards and put units beside inputs. Raw material is entered in kg with up to three decimal places and converted exactly to grams. Rupiah and units use integer inputs. Display uses Indonesian separators; localized strings are never persisted. Query refresh occurs on focus/reconnection, with light polling for stock-sensitive lists. Mutations have no automatic retry.

For an uncertain save, the form freezes the submitted data and offers a manual replay with the same key. Users may close the form and inspect server records; navigation does not create an offline queue. If the client was already offline before sending, it clearly reports that nothing was sent.

Corrections use familiar actions: cancel with a reason, then enter the replacement. Historical records remain visible. Physical stock is reconciled without a per-difference approval bureaucracy.
