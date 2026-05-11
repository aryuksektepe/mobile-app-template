// Riverpod providers for Google Sign In.
//
// ⚠ COPY-PASTE NOTE: rewrite `../../<skill>/snippets/...` imports to
// `package:<your_app>/...` when lifting into your real `lib/`.

import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth-firebase-email/snippets/auth_providers.dart';
import 'google_auth_repository.dart';

final googleSignInProvider = Provider<GoogleSignIn>((_) => GoogleSignIn.instance);

final googleAuthRepoProvider = Provider<GoogleAuthRepository>(
  (ref) => GoogleAuthRepository(
    ref.watch(googleSignInProvider),
    ref.watch(firebaseAuthProvider),
  ),
);

/// Optional: stream of Google authentication events.
final googleAuthEventsProvider = StreamProvider(
  (ref) => ref.watch(googleSignInProvider).authenticationEvents,
);
