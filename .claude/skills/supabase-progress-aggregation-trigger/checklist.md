# Verification Checklist — progress/event aggregation

- [ ] A server-side writer exists (AFTER INSERT trigger / SECURITY DEFINER RPC / pg_cron)
- [ ] Shipped in the SAME migration/phase as the events table (no unowned TODO)
- [ ] Writer is `security definer` + `set search_path = ''`
- [ ] Summary table has owner-only RLS read; no direct client write
- [ ] Non-mocked integration test: insert N events as a real user → summary reflects them
- [ ] No mocked repo standing in for the aggregation
- [ ] db-migration Stage 5.5 evidence (real-stack apply + authenticated path) pasted in phase `## Integration Smoke`
- [ ] INTEGRATION_SMOKE: UI shows non-zero totals/streak after real events
