# Project context and handoff

This repository implements the attached farmer-group specification as a real empty-first application. The main deliverable is source, migrations, tests, documentation and a production build. No runtime business data is bundled. Names that appear inside `tests/` are isolated fixtures; they are never imported by startup, migration, or provisioning.

The installation represents one farmer group in the normal UI. Schema and services preserve organization boundaries so a later organization switcher will not require rewriting stock or financial records. Users belong to one organization; email is globally unique. A platform account has no organization and exists only for intentional CLI administration.

The initial operational flow is farmer/product master data → harvest draft → classification → finalization → physical stock. Grade A can be sold directly; Grade B can be planned then consumed by real production into finished goods. Sales snapshot prices and costs. Physical counts create adjustment events. Reports derive from those events and snapshots.

Engineering files to understand first: `core/transactions.ts`, `modules/inventory/service.ts`, the migration, then each domain service. Express route handlers adapt HTTP and permissions; React helps enter/display data. React must never be the only source of an invariant.

Design constraints: Indonesian UI, calm green palette, mobile numeric keyboards and units, large actions, empty states without fabricated numbers. Static brand illustrations are code-native graphics, not business records or disposable demo assets.

See numbered domain documents for details and `adr/` for intentional decisions. Configuration and actual provider delivery remain deployment work; no unavailable provider is simulated.
