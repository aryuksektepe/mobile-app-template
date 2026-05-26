---
name: background-tasks-workmanager
description: Background tasks via `workmanager` 0.6+ — iOS BGAppRefreshTask / BGProcessingTask + Android WorkManager. Periodic sync, one-shot deferred work, constraints (network, charging), exponential backoff. iOS reality: throttled by OS scheduler — runs only when OS decides (~no guarantees). Android reality: OEM aggressive battery (Xiaomi/Huawei) kills it. NEVER for real-time. Use for non-urgent sync (analytics flush, queued ops, cache refresh).
triggers: [background task, workmanager, BGAppRefreshTask, BGProcessingTask, periodic work, background sync, deferred work, AlarmManager, JobScheduler, OEM battery, doze mode]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  workmanager: "^0.6.0"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# Background Tasks — workmanager

## What this skill does

- Wires `workmanager` 0.6+ for both platforms with a top-level callback function (must be `@pragma('vm:entry-point')`).
- iOS BGAppRefreshTask + BGProcessingTask registration (Info.plist `BGTaskSchedulerPermittedIdentifiers`).
- Android WorkManager: periodic (>=15 min minimum) + one-shot with constraints (network, charging, idle).
- Realistic expectations: iOS runs when OS decides (often hours apart, sometimes never on Low Power Mode); Android OEM aggressive battery killers (Xiaomi MIUI, Huawei EMUI, Samsung) silently kill.
- Exponential backoff via `existingWorkPolicy: keep` + `backoffPolicy: exponential`.
- Doze/App Standby awareness on Android — your work runs in maintenance windows only.
- NOT for real-time — use FCM data push + foreground service for that.

## What this skill does NOT do

- Does NOT replace real-time push (use `notifications-fcm` with `priority: high`).
- Does NOT replace foreground services (`workmanager` is deferred work; foreground service requires native Kotlin).

## Decision tree

**Q1: Sync interval?**
- < 15 min — NOT POSSIBLE. Android WorkManager hard floor is 15 min. iOS BGAppRefreshTask aims for ~hour scale.
- 15 min – 1 hour — `registerPeriodicTask(frequency: 15min)` on Android; iOS does best-effort.
- > 1 hour — same registration; iOS more reliable at this cadence.

**Q2: Need delivery guarantee?**
- NO — workmanager is non-guaranteed. iOS may skip, Android OEMs may kill.
- YES — wrong tool. Use FCM data push (server-driven) + foreground service for the work.

## Quick start

```bash
flutter pub add workmanager
```

iOS: enable Background Modes → Background fetch + Background processing in Xcode Capabilities. Add the task identifiers to Info.plist `BGTaskSchedulerPermittedIdentifiers`.

Apply [snippets/background_setup.dart](snippets/background_setup.dart).

## Code patterns

| Need | File |
|---|---|
| Top-level callback + registration | [snippets/background_setup.dart](snippets/background_setup.dart) |
| iOS Info.plist BGTask identifiers | [snippets/Info.plist.snippet.xml](snippets/Info.plist.snippet.xml) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. iOS task never runs — `BGTaskSchedulerPermittedIdentifiers` not in Info.plist OR task ID mismatch.
2. Android Xiaomi/Huawei: task runs in dev but never on user device — OEM battery killer; surface "Auto-start" / "Protected apps" settings.
3. Top-level callback not `@pragma('vm:entry-point')` → tree-shaken in release.
4. Task does network work but device on cellular + constraint NetworkType.unmetered → silently never runs.
5. Task overruns iOS 30s budget → killed; subsequent runs throttled further.

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none; coordinates with `notifications-fcm` for OS battery workaround dialogs)
