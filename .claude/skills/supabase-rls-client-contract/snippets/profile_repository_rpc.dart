// Client side of the contract: NEVER `from('profiles').upsert(...)`.
// Call the sanctioned SECURITY DEFINER RPC. The server decides the row
// (auth.uid()) and the allowed columns — the client only sends values.

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository(this._supabase);
  final SupabaseClient _supabase;

  /// Returns the updated profile row as a map (jsonb from the RPC).
  /// Throws [PostgrestException] on RLS / auth / FK failures — do NOT swallow:
  /// these are exactly the failures mocked tests hide.
  Future<Map<String, dynamic>> upsertOwnProfile({
    String? displayName,
    String? avatarUrl,
    bool? onboardingComplete,
  }) async {
    final result = await _supabase.rpc(
      'upsert_own_profile',
      params: {
        if (displayName != null) 'p_display_name': displayName,
        if (avatarUrl != null) 'p_avatar_url': avatarUrl,
        if (onboardingComplete != null)
          'p_onboarding_complete': onboardingComplete,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }
}
