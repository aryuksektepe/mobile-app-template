// background_setup.dart — workmanager 0.6 setup
//
// Place callbackDispatcher at TOP LEVEL (not in a class) with @pragma — else
// release-mode tree shake removes it and tasks silently never fire.
//
// Initialize in main():
//   await BackgroundService.init();
//   await BackgroundService.scheduleSync();

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

const String kSyncTaskId = 'com.yourcompany.app.sync';
const String kCleanupTaskId = 'com.yourcompany.app.cleanup';

@pragma('vm:entry-point')
void callbackDispatcher() {
  // Top-level isolate entry. Must call executeTask + return Future<bool>.
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case kSyncTaskId:
          await _doSync();
          break;
        case kCleanupTaskId:
          await _doCleanup();
          break;
      }
      return true; // success
    } catch (e) {
      if (kDebugMode) print('background task $task failed: $e');
      return false; // workmanager will retry per backoff
    }
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode, // shows debug notifications on Android
    );
  }

  /// Periodic sync (Android: 15 min min; iOS: best-effort).
  static Future<void> scheduleSync() async {
    await Workmanager().registerPeriodicTask(
      kSyncTaskId,
      kSyncTaskId,
      frequency: const Duration(minutes: 15),  // Android floor
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// One-shot deferred work (e.g., flush analytics queue when charging + on WiFi)
  static Future<void> scheduleCleanup() async {
    await Workmanager().registerOneOffTask(
      kCleanupTaskId,
      kCleanupTaskId,
      initialDelay: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresCharging: true,
      ),
    );
  }

  static Future<void> cancelAll() => Workmanager().cancelAll();
}

// ---- Placeholder work functions — wire to your services ----

Future<void> _doSync() async {
  // e.g., flush pending ops queue (per `connectivity-offline-ux`)
  // Drift + your repository here. Keep under 30s on iOS!
}

Future<void> _doCleanup() async {
  // e.g., clear old cache files, vacuum DB
}
