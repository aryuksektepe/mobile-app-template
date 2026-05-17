// Contract-parity test: assert the EXACT method + body field names the client
// sends, against the function's contract. `any(named:'body')` is forbidden
// here — that is precisely what let ADR-032/035 ship.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockFunctions extends Mock implements FunctionsClient {}
class MockSupabase extends Mock implements SupabaseClient {}

void main() {
  test('deleteAccount calls delete_account as POST with {otp_token}', () async {
    final fns = MockFunctions();
    final sb = MockSupabase();
    when(() => sb.functions).thenReturn(fns);
    when(() => fns.invoke(
          any(),
          method: any(named: 'method'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => FunctionResponse(data: {'ok': true}, status: 200));

    await AccountRepository(sb).deleteAccount('otp-123');

    final captured = verify(() => fns.invoke(
          captureAny(),
          method: captureAny(named: 'method'),
          body: captureAny(named: 'body'),
        )).captured;

    expect(captured[0], 'delete_account');                 // fn name
    expect(captured[1], HttpMethod.post);                  // method contract
    expect(captured[2], {'otp_token': 'otp-123'});         // EXACT field name
    // Asserting the concrete shape — not `any` — is the whole point.
  });
}
