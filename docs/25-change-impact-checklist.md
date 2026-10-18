# Change-impact checklist

Copy into each substantial change/review. Fill `affected` and notes rather than mechanically checking every box.

```yaml
change_impact_review:
  domain_logic: { affected: false, notes: '' }
  database: { affected: false, migration_required: false, notes: '' }
  harvest: { affected: false, notes: '' }
  inventory: { affected: false, notes: '' }
  production: { affected: false, notes: '' }
  hpp: { affected: false, notes: '' }
  pricing_history: { affected: false, notes: '' }
  sales: { affected: false, notes: '' }
  reporting: { affected: false, notes: '' }
  audit: { affected: false, notes: '' }
  authentication: { affected: false, notes: '' }
  authorization: { affected: false, notes: '' }
  public_data_boundary: { affected: false, notes: '' }
  idempotency: { affected: false, notes: '' }
  concurrency: { affected: false, notes: '' }
  pwa: { affected: false, notes: '' }
  flutter_mobile_client: { affected: false, notes: '' }
  tests: { update_required: false, evidence: '' }
  documentation: { update_required: false, notes: '' }
```

Before approval/release, ask: Can this change create stock without a cause? Can it change old prices/HPP? Does it turn a plan into consumption? Can a retry duplicate a sale? Can an Admin gain Owner privileges? Can another organization attach/read the entity? Can a public DTO or signed file leak private data? Does PDF still use the same report object? Can service-worker or mobile behavior queue/cache a transaction? Does the Flutter client still follow the same API/domain rules? Is the integration genuinely contacted when success is asserted? Does an empty installation still work without business seeds?