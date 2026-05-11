// iOS Keychain entries SURVIVE app uninstall (by design — Apple's stance).
// On Android, app data IS cleared on uninstall, so this is iOS-specific.
//
// Without this wipe:
//   1. User installs app, signs in. Refresh token written to Keychain.
//   2. User uninstalls.
//   3. NEW user installs app on same device.
//   4. App reads Keychain → finds old refresh token → silently signs in
//      as PREVIOUS user. Privacy violation + KVKK breach.
//
// Pattern: store a sentinel in shared_preferences (which IS cleared on
// uninstall). If missing → first launch after install → wipe Keychain.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFirstLaunchSentinel = 'app.first_launch_done';

/// Run ONCE at app start, BEFORE any read/write to secure storage.
/// Pre-condition: WidgetsFlutterBinding.ensureInitialized() called.
Future<void> ensureFreshInstallCleared() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = !(prefs.getBool(_kFirstLaunchSentinel) ?? false);

  if (isFirstLaunch) {
    // Wipe leftover Keychain from prior install (iOS only matters; Android no-op).
    await const FlutterSecureStorage().deleteAll();
    await prefs.setBool(_kFirstLaunchSentinel, true);
  }
}
