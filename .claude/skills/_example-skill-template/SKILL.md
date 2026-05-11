---
name: _example-skill-template
description: Reference structure for what a real skill directory looks like. NOT a real skill — don't match against this. Skill-extractor uses this as the canonical structure when creating new skills. Delete this directory once you have at least one real extracted skill.
triggers: [example, template, reference]
platforms: [ios, android]
last_verified: 2026-05-10
flutter_min: "3.27.0"
extracted_from_phase: n/a
recurrence_count: 0
validation_status: pre-seeded   # pre-seeded | battle-tested
depends_on: []
---

# Example Skill Template (NOT a real skill)

This directory shows what a skill produced by `skill-extractor` looks like.

A real skill (e.g. `notifications-fcm`, `auth-firebase-email`, `subs-revenuecat`) follows this exact structure.

## Decision Tree

(In a real skill: 3-question decision tree to determine which snippet/path to take.)

1. Question?
   - Yes → use snippet A
   - No → use snippet B

## What this skill does

- Bullet 1
- Bullet 2

## What this skill does NOT do

- Bullet (explicit non-scope)

## Quick start

```bash
# 3 commands max
flutter pub add <packages>
<setup command>
# See implementation.md for code wiring
```

## Step-by-step

For full setup → see [implementation.md](implementation.md).

## Code

Paste-ready snippets in [snippets/](snippets/).

## Known pitfalls

DON'T re-discover bugs others paid for → [pitfalls.md](pitfalls.md).

## Verification

After implementing, run [checklist.md](checklist.md).

## Skill metadata

- Extracted from: phase {id}
- Last verified: {YYYY-MM-DD}
- Flutter min: {version}
- Depends on: {other skills, if any}
