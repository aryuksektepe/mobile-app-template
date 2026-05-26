# freezed + json_serializable — Verification Checklist

- [ ] `freezed_annotation` + `json_annotation` in `dependencies`
- [ ] `freezed` + `json_serializable` + `build_runner` in `dev_dependencies`
- [ ] All models use `@freezed` annotation
- [ ] Sealed unions use `@freezed sealed class` (3.x style)
- [ ] `factory Foo.fromJson(...) => _$FooFromJson(json);` present on every JSON-deserializable
- [ ] Nested freezed parents have `@JsonSerializable(explicitToJson: true)`
- [ ] `@JsonKey(name:)` used for snake_case backend fields
- [ ] DateTime fields use `@DateTimeConverter()` (UTC discipline)
- [ ] Enum-from-backend uses custom converter OR `@JsonValue('UPPER') lowerCase`
- [ ] `dart run build_runner build --delete-conflicting-outputs` ran clean
- [ ] Generated files committed to repo
- [ ] CI generated-clean gate green (see `regen-clean-after-diagnostics`)
- [ ] ProGuard keep rules for model package (see `ios-android-hardening`)
- [ ] Unit tests cover fromJson/toJson round-trip for every model
