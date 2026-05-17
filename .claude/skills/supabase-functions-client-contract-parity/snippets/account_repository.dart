import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository {
  AccountRepository(this._supabase);
  final SupabaseClient _supabase;

  /// Contract: POST /functions/v1/delete_account, body { otp_token }.
  /// Field name + method match supabase/functions/delete_account/index.ts
  /// EXACTLY. (ADR-035 shipped because the client sent `token`.)
  Future<void> deleteAccount(String otpToken) async {
    final res = await _supabase.functions.invoke(
      'delete_account',
      method: HttpMethod.post,           // not GET (ADR-032 class)
      body: {'otp_token': otpToken},     // not 'token' (ADR-035)
    );
    if (res.status < 200 || res.status >= 300) {
      throw FunctionException(
        status: res.status,
        details: res.data,
        reasonPhrase: 'delete_account contract failure',
      );
    }
  }
}
