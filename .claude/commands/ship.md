---
description: Release pipeline'ı tetikle — release-manager agent'ı.
allowed-tools: Task, Read, Write, Edit, Bash
---

# /ship

Final release pipeline'ı başlat. **release-manager** agent'ı:
1. Pre-flight gate (security pre-release + perf fresh + compliance + aso + features)
2. Version bump
3. Release notes generation
4. Build + sign + upload (CI'ye komut emit eder, kendi çalıştırmaz)
5. Phased rollout monitoring

## Talimat

`release-manager` Task'ını başlat:

```
subagent_type: release-manager
description: Run release pipeline
prompt: User invoked /ship. Run pre-flight gate per release-manager.md §3 Stage 1. If any gate fails, halt with gap report. If all gates pass, proceed through Stages 2-8 (version bump → notes → build commands → verification → metadata sync → submission → rollout monitoring). Emit operator runbook.
```

User input: $ARGUMENTS
