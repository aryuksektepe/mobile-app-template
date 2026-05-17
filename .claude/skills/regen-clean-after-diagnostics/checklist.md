# Verification Checklist — regen-clean / CI determinism

- [ ] Pre-push guard runs `build_runner` and fails on generated drift
- [ ] Source changes + their regenerated `.g.dart`/`.freezed.dart` committed together
- [ ] Deterministic generated files (.g/.freezed/l10n) ARE in the `git diff --exit-code` gate
- [ ] Non-deterministic artifacts either made deterministic (fixed stamp/sorted keys) OR excluded by pathspec — and that exclude list matches `ci.yml`
- [ ] No `**/*.dart` blanket exclusion (gate still has teeth)
- [ ] Reports use `--define GENERATED_AT=<git commit date>`, not `DateTime.now()`
- [ ] Push discipline: batched, one CI run per batch (CLAUDE.md §9)
- [ ] No `--no-verify` bypass of the generated-clean gate
