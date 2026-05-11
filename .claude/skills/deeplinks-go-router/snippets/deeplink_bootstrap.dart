// Cold-start deep link capture. MUST run BEFORE runApp() to prevent race
// with go_router's initialLocation.

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLinksProvider = Provider<AppLinks>((_) => AppLinks());

/// Stashed link — read by go_router redirect, cleared after navigation.
final pendingDeepLinkProvider = StateProvider<Uri?>((_) => null);

/// Call from main() AFTER ensureInitialized(), BEFORE runApp().
Future<void> captureColdStartLink(ProviderContainer container) async {
  final appLinks = container.read(appLinksProvider);
  final initial = await appLinks.getInitialAppLink();
  if (initial != null) {
    container.read(pendingDeepLinkProvider.notifier).state = initial;
  }
}

/// Subscribe to warm-start links. Cancel sub on dispose.
StreamSubscription<Uri> subscribeToWarmLinks(WidgetRef ref) {
  return ref.read(appLinksProvider).uriLinkStream.listen((uri) {
    ref.read(pendingDeepLinkProvider.notifier).state = uri;
  });
}

// Example main():
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(...);
//
//   final container = ProviderContainer();
//   await captureColdStartLink(container);
//
//   runApp(UncontrolledProviderScope(
//     container: container,
//     child: const App(),
//   ));
// }
