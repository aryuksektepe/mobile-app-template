// Background message handler + bootstrap call. Wire from main()
// AFTER Firebase.initializeApp() but BEFORE runApp().
//
// CRITICAL:
// - Background handler MUST be a top-level (or static) function
// - MUST have @pragma('vm:entry-point') (or it gets tree-shaken in release)
// - MUST initialize Firebase itself — runs in a separate isolate

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate — UI work is impossible.
  // Tasks possible: persist payload to local DB / shared_preferences,
  //                 update badge count via flutter_local_notifications,
  //                 hit your backend (limited time budget — ~30s on iOS).
  await Firebase.initializeApp();

  // Optional: bookkeeping, e.g., increment unread counter.
  // await SharedPreferences.getInstance().then((p) =>
  //   p.setInt('unread', (p.getInt('unread') ?? 0) + 1));
}

/// Call from your bootstrap() AFTER Firebase.initializeApp().
void registerBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}
