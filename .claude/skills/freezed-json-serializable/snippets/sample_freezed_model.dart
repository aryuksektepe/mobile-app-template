// Sample freezed model + sealed union + custom converters.
// Run: dart run build_runner build --delete-conflicting-outputs

import 'package:freezed_annotation/freezed_annotation.dart';

part 'sample_freezed_model.freezed.dart';
part 'sample_freezed_model.g.dart';

// ---- Simple data class ----

@freezed
class User with _$User {
  const factory User({
    required String id,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'email_verified') @Default(false) bool emailVerified,
    @DateTimeConverter() required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

// ---- Sealed union (exhaustive when/map) ----

@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.idle() = AuthIdle;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
  const factory AuthState.error(String message) = AuthError;
}

// Usage in UI:
//   final w = switch (state) {
//     AuthIdle() => const WelcomeScreen(),
//     AuthLoading() => const CircularProgressIndicator(),
//     AuthAuthenticated(:final user) => HomeScreen(user: user),
//     AuthError(:final message) => ErrorScreen(message: message),
//   };
// Or for older Dart pattern matching:
//   state.when(
//     idle: () => ...,
//     loading: () => ...,
//     authenticated: (user) => ...,
//     error: (message) => ...,
//   );

// ---- Custom converter: UTC DateTime ↔ ISO-8601 string ----

class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();
  @override
  DateTime fromJson(String json) => DateTime.parse(json).toUtc();
  @override
  String toJson(DateTime object) => object.toUtc().toIso8601String();
}

// ---- Custom converter: backend-string enum ----

enum SubscriptionTier { free, plus, pro }

class SubscriptionTierConverter implements JsonConverter<SubscriptionTier, String> {
  const SubscriptionTierConverter();
  @override
  SubscriptionTier fromJson(String json) =>
      SubscriptionTier.values.firstWhere((t) => t.name == json, orElse: () => SubscriptionTier.free);
  @override
  String toJson(SubscriptionTier object) => object.name;
}

// ---- Nested freezed (parent must opt into explicitToJson for nested toJson to work) ----

@freezed
class Profile with _$Profile {
  // explicitToJson: true ensures nested `user.toJson()` is called instead of toString()
  @JsonSerializable(explicitToJson: true)
  const factory Profile({
    required User user,
    required String bio,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);
}
