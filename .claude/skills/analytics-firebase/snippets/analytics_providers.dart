// Riverpod providers for Firebase Analytics + GoRouter screen-tracking observer.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>(
  (_) => FirebaseAnalytics.instance,
);

final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver>(
  (ref) => FirebaseAnalyticsObserver(analytics: ref.read(firebaseAnalyticsProvider)),
);

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref.read(firebaseAnalyticsProvider)),
);

/// Add to GoRouter:
///   GoRouter(
///     observers: [ref.read(analyticsObserverProvider)],
///     ...
///   )
///
/// Then every navigation fires a `screen_view` event automatically.
/// For routes without a unique path (modal sheets, tabs), call
/// analytics.logScreenView(screenName: 'cart_modal') manually.
