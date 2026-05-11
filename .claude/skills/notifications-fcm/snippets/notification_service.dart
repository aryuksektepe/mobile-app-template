// NotificationService — single entry point for:
//  1. Local notifications init + Android channel creation
//  2. Foreground display (FCM does NOT auto-show in foreground)
//  3. Tap routing in all 3 states (terminated/background/foreground)
//
// Use the pendingDeepLinkProvider pattern to route AFTER auth is hydrated
// (avoids cold-start race where link arrives before router is ready).

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read by the GoRouter redirect after auth state hydrated.
final pendingDeepLinkProvider = StateProvider<String?>((_) => null);

class NotificationService {
  NotificationService(this._ref);
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Local notifications init.
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings(
      // We do soft-ask elsewhere — don't request at init.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // 2. Android channel — must exist BEFORE any push arrives.
    // Channel settings are immutable after creation. Bump ID if you need to change importance.
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'default_channel',
          'General',
          description: 'Transactional and system notifications',
          importance: Importance.high,
        ));

    // 3. Foreground listener — FCM does NOT auto-show.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // 4. Warm-start tap (app in background, user tapped notification).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNavigation);

    // 5. Cold-start tap (app launched FROM notification tap).
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Defer until first frame so router is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleNavigation(initial));
    }
  }

  /// Soft-ask: call from in-context CTA, NOT from main().
  /// On Android 13+ this also triggers the POST_NOTIFICATIONS runtime prompt.
  Future<NotificationSettings> requestPermission({bool provisional = false}) async {
    return FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: provisional,
    );
  }

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'default_channel',
          'General',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(m.data),
    );
  }

  void _onLocalTap(NotificationResponse r) {
    if (r.payload == null) return;
    try {
      final data = jsonDecode(r.payload!) as Map<String, dynamic>;
      final route = data['route'];
      if (route is String) {
        _ref.read(pendingDeepLinkProvider.notifier).state = route;
      }
    } catch (e) {
      if (kDebugMode) print('[Notif] failed to parse payload: $e');
    }
  }

  void _handleNavigation(RemoteMessage m) {
    final route = m.data['route'];
    if (route is String) {
      _ref.read(pendingDeepLinkProvider.notifier).state = route;
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  NotificationService.new,
);
