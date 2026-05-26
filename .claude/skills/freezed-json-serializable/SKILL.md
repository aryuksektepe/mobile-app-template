---
name: freezed-json-serializable
description: freezed 3.x + json_serializable patterns — sealed unions with exhaustive `when`/`map`, `@JsonKey(name:)` for snake_case backend, custom converters for DateTime/Enum/Decimal, `@Default()` with null safety, build_runner watch + clean cycles, code-gen drift catching, generated-clean CI gate. Use whenever a model class or sealed state union is needed.
triggers: [freezed, json_serializable, sealed class, sealed union, when map, @Default, @JsonKey, build_runner watch, codegen, .g.dart, .freezed.dart, custom converter, copyWith, generated diff CI]
platforms: [ios, android]
last_verified: 2026-05-26
flutter_min: "3.22.0"
package_versions:
  freezed: "^3.0.0"
  freezed_annotation: "^3.0.0"
  json_annotation: "^4.9.0"
  json_serializable: "^6.8.0"
  build_runner: "^2.4.13"
extracted_from_phase: pre-seeded
recurrence_count: 0
validation_status: pre-seeded
depends_on: []
---

# freezed + json_serializable

## What this skill does

- Immutable data classes with `copyWith`, `==`, `hashCode`, `toString`.
- Sealed unions (`@freezed sealed class State`) with exhaustive `when` / `map`.
- `fromJson` / `toJson` via json_serializable with `@JsonKey(name: 'snake_case')`.
- Custom converters: `DateTimeConverter` (UTC), `DecimalConverter`, `EnumConverter` for backend-string enums.
- `@Default(...)` for safe defaults under null safety.
- Build_runner workflow: `--delete-conflicting-outputs`, `watch` for dev, clean cycle before commit.
- CI generated-clean gate (see also `regen-clean-after-diagnostics`).

## What this skill does NOT do

- Does NOT replace Riverpod state — freezed is the DTO; Riverpod is the state holder.
- Does NOT cover JsonSerializable's `explicitToJson: true` for nested freezed (the snippet handles it but check per-model).

## Decision tree

**Q1: Simple data or sealed union?**
- SIMPLE — `@freezed class Foo with _$Foo { const factory Foo({ ... }) = _Foo; factory Foo.fromJson(...) = _$FooFromJson; }`
- UNION — `@freezed sealed class State with _$State { const factory State.idle() = StateIdle; const factory State.loading() = StateLoading; ... }`. Exhaustive `when` / `map` becomes binding.

**Q2: Backend in snake_case?**
- YES → `@JsonKey(name: 'user_id') required int userId,` per field. OR set `@JsonSerializable(fieldRename: FieldRename.snake)` per class to auto-convert.

## Quick start

```bash
flutter pub add freezed_annotation json_annotation
flutter pub add --dev build_runner freezed json_serializable
```

Apply [snippets/sample_freezed_model.dart](snippets/sample_freezed_model.dart).

Run codegen:
```bash
dart run build_runner build --delete-conflicting-outputs
# Dev watch mode:
dart run build_runner watch --delete-conflicting-outputs
```

## Code patterns

| Need | File |
|---|---|
| Data model + sealed union + converters | [snippets/sample_freezed_model.dart](snippets/sample_freezed_model.dart) |

## Known pitfalls

→ [pitfalls.md](pitfalls.md). Top 5:
1. `default Dart3 behavior` warning — freezed 3.x requires sealed class for unions; old `union` style breaks.
2. `_$FooFromJson` not generated → forgot `factory Foo.fromJson(Map<String, dynamic> json) => _$FooFromJson(json);`.
3. Nested freezed: parent's `toJson()` shows child as `{}`. Need `@JsonSerializable(explicitToJson: true)`.
4. CI diff fails because generated files committed differ from fresh build_runner. See `regen-clean-after-diagnostics`.
5. ProGuard strips freezed runtime when reflection-based fromJson is used. Add keep rules (per `ios-android-hardening`).

## Verification

→ [checklist.md](checklist.md).

## Skill metadata
- Validation status: **pre-seeded**
- Last verified: 2026-05-26
- Depends on: (none)
