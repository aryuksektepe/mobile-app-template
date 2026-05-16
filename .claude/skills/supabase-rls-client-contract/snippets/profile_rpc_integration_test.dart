// NON-MOCKED integration test. Runs against a REAL local Supabase
// (`supabase start`). This is the test that would have caught the shipped
// breakage — a mocked datasource test cannot see RLS / column-guard / FK.
//
// NOTE: deliberately NOT tagged `mocked`, so the `backend-integration` CI job
// (`flutter test integration_test/ --exclude-tags=mocked`) runs it.
//
// Run locally:
//   supabase start
//   flutter test integration_test/profile_rpc_integration_test.dart \
//     --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
//     --dart-define=SUPABASE_ANON_KEY=<local anon key from `supabase start`>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClient supabase;

  setUpAll(() async {
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    supabase = Supabase.instance.client;
    // Real signed-in session — exercises auth.uid() inside the RPC.
    await supabase.auth.signInWithPassword(
      email: 'integration+profile@example.com',
      password: 'integration-pw-123',
    );
  });

  test('upsert_own_profile writes the caller row through the RPC', () async {
    final updated = await supabase.rpc('upsert_own_profile', params: {
      'p_display_name': 'Integration User',
      'p_onboarding_complete': true,
    });

    final row = Map<String, dynamic>.from(updated as Map);
    expect(row['display_name'], 'Integration User');
    expect(row['onboarding_complete'], true);
    expect(row['id'], supabase.auth.currentUser!.id);
  });

  test('direct table write is correctly BLOCKED (proves the guard works)',
      () async {
    // The whole reason the RPC exists: this path must fail, not silently pass.
    expect(
      () => supabase.from('profiles').update({
        'display_name': 'hacker',
      }).eq('id', supabase.auth.currentUser!.id),
      throwsA(isA<PostgrestException>()),
    );
  });
}
