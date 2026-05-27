// ============================================================================
// dto-known-set-pattern.dart
// ----------------------------------------------------------------------------
// Correct shape for a DTO that uses a `known` Set + `extras` Map to roundtrip
// columns. This is a common ADR-008-style forward-compat pattern: known
// columns become typed fields, unknown columns survive in `extras` so the
// client can read newer-server JSON without breaking.
//
// THE BUG THIS PREVENTS (Phase-28 BUG-28-02 / CR-28-01):
//   * You add `scope_id` to the SELECT in your remote datasource.
//   * Your DTO has a `known` set used to gate the extras-map.
//   * You forget to add `'scope_id'` to the `known` set OR you forget to
//     declare `final String? scopeId` on the class itself.
//   * Result: the column data exists in JSON, gets routed to `extras` map,
//     and the domain layer is scope-blind because the typed field doesn't
//     exist or is always null.
//
// ============================================================================

// Replace:
//   Child         — your DTO name (e.g. ModuleDto, UnitDto, ProgressEventDto)
//   <child_table> — the table name as it appears in JSON keys
//   scope_id      — the new column you're adding

class ChildDto {
  // 1️⃣ Declare the typed field on the class. Initially nullable; tighten
  //    to non-null once Step 4 of the SQL rollout (NOT NULL constraint) is
  //    deployed and verified.
  final String id;
  final String? scopeId; // <-- NEW: the scoping column

  // ...other typed fields
  final String title;
  final DateTime updatedAt;

  // 2️⃣ Carry-over for unknown JSON keys (ADR-008-style forward compat).
  final Map<String, dynamic> extras;

  const ChildDto({
    required this.id,
    required this.scopeId, // <-- NEW
    required this.title,
    required this.updatedAt,
    this.extras = const {},
  });

  // 3️⃣ The `known` Set MUST contain every column the DTO claims to handle.
  //    Anything NOT in this set gets routed to `extras`.
  //    ⚠️ Forgetting to add a new column here is the most common form of
  //       the BUG-28-02 bug — the column data won't be lost (because the
  //       typed field assignment in `fromJson` still works), but `toJson`
  //       may drop it AND the contract is broken.
  static const _known = <String>{
    'id',
    'scope_id', // <-- NEW
    'title',
    'updated_at',
  };

  factory ChildDto.fromJson(Map<String, dynamic> json) {
    final extras = <String, dynamic>{};
    for (final entry in json.entries) {
      if (!_known.contains(entry.key)) {
        extras[entry.key] = entry.value;
      }
    }
    return ChildDto(
      id: json['id'] as String,
      scopeId: json['scope_id'] as String?, // <-- NEW
      title: json['title'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      extras: extras,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (scopeId != null) 'scope_id': scopeId, // <-- NEW
        'title': title,
        'updated_at': updatedAt.toIso8601String(),
        ...extras,
      };
}

// ============================================================================
// THE DOMAIN ENTITY (Layer 6) — DTO is NOT enough, the entity also needs scopeId.
// ============================================================================

// (using freezed; adapt to your style if you're not on freezed)
//
// @freezed
// class Child with _$Child {
//   const factory Child({
//     required String id,
//     String? scopeId,   // <-- MUST be added here too
//     required String title,
//     required DateTime updatedAt,
//   }) = _Child;
// }

// ============================================================================
// THE MAPPER (Layer 7) — silent drops happen here. Easy line to miss.
// ============================================================================

// extension ChildDtoX on ChildDto {
//   Child toDomain() => Child(
//     id: id,
//     scopeId: scopeId,   // <-- silent drop happens IF this line is missing
//     title: title,
//     updatedAt: updatedAt,
//   );
// }

// ============================================================================
// THE DRIFT WRITE PATH (Layer 8) — local cache also needs the column.
// ============================================================================

// // In your Drift table definition:
// class ChildTable extends Table {
//   TextColumn get id => text()();
//   TextColumn get scopeId => text().nullable()();   // <-- NEW
//   TextColumn get title => text()();
//   DateTimeColumn get updatedAt => dateTime()();
// }
//
// // In your local datasource upsert:
// await into(childTable).insert(
//   ChildTableCompanion.insert(
//     id: dto.id,
//     scopeId: Value(dto.scopeId),   // <-- silent drop happens IF missing
//     title: dto.title,
//     updatedAt: dto.updatedAt,
//   ),
//   mode: InsertMode.insertOrReplace,
// );
//
// // In your local datasource read (row → DTO):
// ChildDto _rowToDto(ChildRow row) => ChildDto(
//   id: row.id,
//   scopeId: row.scopeId,   // <-- silent drop happens IF missing
//   title: row.title,
//   updatedAt: row.updatedAt,
// );

// ============================================================================
// GREP-DRIVEN VERIFICATION
// ============================================================================
//
// Run this AT MINIMUM after wiring everything up:
//
//   grep -rn 'scopeId\|scope_id' \
//     lib/.../data/dtos/ \
//     lib/.../domain/entities/ \
//     lib/.../data/mappers/ \
//     lib/.../data/datasources/ \
//     lib/.../core/database/
//
// Expect AT LEAST 8 hits across at least 4 distinct files (one per layer).
// If any layer has 0 hits → you missed it → go back and wire it.
