// ⚠ COPY-PASTE NOTE: rewrite `../../<skill>/...` to `package:<your_app>/...`
// when lifting into your real `lib/`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth-firebase-email/snippets/auth_providers.dart';
import 'apple_auth_repository.dart';

final appleAuthRepoProvider = Provider<AppleAuthRepository>(
  (ref) => AppleAuthRepository(ref.watch(firebaseAuthProvider)),
);
