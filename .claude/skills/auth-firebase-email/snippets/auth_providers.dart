// Riverpod auth providers.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authRepoProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);

/// Use for ROUTING decisions (login/logout transitions).
/// Fires once on app start with current user (or null), then on auth changes.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// Use for WIDGETS that care about profile updates (displayName, photoURL,
/// emailVerified flips).
final userChangesProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).userChanges(),
);

/// Convenience: typed `bool isLoggedIn`.
final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).valueOrNull != null,
);

/// Convenience: typed `bool emailVerified`.
final emailVerifiedProvider = Provider<bool>(
  (ref) => ref.watch(userChangesProvider).valueOrNull?.emailVerified ?? false,
);
