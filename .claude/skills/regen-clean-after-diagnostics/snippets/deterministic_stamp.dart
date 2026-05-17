// Deterministic generation stamp. Using DateTime.now() makes every generated
// report differ → the CI generated-clean gate red-fails on noise. Take the
// stamp from the environment (git commit date in CI) so identical inputs
// produce identical output.
import 'dart:convert';

String generatedAt() =>
    const String.fromEnvironment('GENERATED_AT', defaultValue: 'unset');
// Invoke with: --define=GENERATED_AT=$(git log -1 --format=%cI)

/// Serialize deterministically: sort keys, fixed stamp. Same inputs → same
/// bytes → diff gate stays meaningful (only real changes show).
String renderReport(Map<String, Object?> data) {
  final sorted = <String, Object?>{};
  for (final k in data.keys.toList()..sort()) {
    sorted[k] = data[k];
  }
  sorted['generated_at'] = generatedAt(); // NOT DateTime.now()
  return const JsonEncoder.withIndent('  ').convert(sorted);
}
