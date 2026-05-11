// Soft-ask permission pattern. Show a custom screen explaining WHY before
// triggering the OS prompt. Without this, denial rate is very high.
//
// On iOS: OS prompt can only be shown ONCE per install; if user denies,
//          you must direct them to Settings.
// On Android 13+: POST_NOTIFICATIONS prompt. Less restrictive — re-shown
//                  on each app reinstall.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';

class SoftAskNotificationsScreen extends ConsumerWidget {
  const SoftAskNotificationsScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.notifications_active_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                "Bildirimleri açalım mı?",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "Sipariş güncellemeleri, kampanyalar ve önemli hatırlatmalar "
                "için bildirim göndereceğiz. İstediğin zaman ayarlardan "
                "kapatabilirsin.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () async {
                  final settings = await ref
                      .read(notificationServiceProvider)
                      .requestPermission();
                  // Log the outcome for analytics
                  // ref.read(analyticsServiceProvider).logEvent(
                  //   name: 'notif_permission',
                  //   parameters: {'status': settings.authorizationStatus.name},
                  // );
                  onDone();
                },
                child: const Text("İzin Ver"),
              ),
              TextButton(
                onPressed: onDone,
                child: const Text("Şimdi Değil"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper: check current status without prompting.
Future<bool> isNotificationsAuthorized() async {
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}
