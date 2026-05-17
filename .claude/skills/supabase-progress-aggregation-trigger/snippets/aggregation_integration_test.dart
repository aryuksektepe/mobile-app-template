// NON-MOCKED: real local Supabase. Insert events as a real user, assert the
// summary updates. A mocked repo returning a fake summary hid ADR-028.
// Not tagged 'mocked' → runs in backend-integration CI.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('inserting progress_events updates progress_summary (trigger runs)',
      () async {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    final c = Supabase.instance.client;
    await c.auth.signInWithPassword(
      email: 'integration+agg@example.com', password: 'integration-pw-123');
    final uid = c.auth.currentUser!.id;

    await c.from('progress_events').insert({'user_id': uid, 'xp': 10});
    await c.from('progress_events').insert({'user_id': uid, 'xp': 15});

    final summary = await c
        .from('progress_summary')
        .select()
        .eq('user_id', uid)
        .single();

    expect(summary['total_xp'], 25,
        reason: 'Aggregation writer missing — events never rolled up (ADR-028)');
  });
}
