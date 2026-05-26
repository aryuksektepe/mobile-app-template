// Connectivity + reachability — Riverpod stream + global offline banner.
//
// Wire the banner in your MaterialApp.router builder:
//   MaterialApp.router(
//     builder: (ctx, child) => Stack(children: [child!, const OfflineBanner()]),
//     ...
//   )

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

enum Reachability { online, offline, checking }

/// Stream of CONNECTIVITY (interface presence). Updates fast on transition.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// Stream of REACHABILITY (actual internet). TCP probes a real endpoint.
/// Debounced so brief drops don't trigger flicker.
final reachabilityProvider = StreamProvider<Reachability>((ref) {
  // When connectivity changes → re-probe reachability after 1s
  final controller = StreamController<Reachability>.broadcast();
  Timer? debounce;
  void recheck() {
    debounce?.cancel();
    controller.add(Reachability.checking);
    debounce = Timer(const Duration(milliseconds: 1000), () async {
      final hasInternet = await InternetConnection().hasInternetAccess;
      controller.add(hasInternet ? Reachability.online : Reachability.offline);
    });
  }
  recheck();
  final sub = Connectivity().onConnectivityChanged.listen((_) => recheck());
  // Also re-probe on app resume (handled by an external lifecycle observer that
  // calls `ref.invalidate(reachabilityProvider)`)
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reach = ref.watch(reachabilityProvider).valueOrNull ?? Reachability.checking;
    if (reach != Reachability.offline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, color: theme.colorScheme.onErrorContainer, size: 18),
                const SizedBox(width: 8),
                Text(
                  'İnternet bağlantısı yok',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
