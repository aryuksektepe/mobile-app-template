// Force-update gate. Block app if current build < min_supported_build,
// OR show maintenance screen if maintenance_mode == true.
//
// Wrap your home/route widget with this; or place at the top of GoRouter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'remote_config.dart';

class AppGate extends ConsumerWidget {
  const AppGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).valueOrNull;

    // Defaults are loaded synchronously, so .valueOrNull is rarely null.
    // If null (cold start race), pass through.
    if (config == null) return child;

    if (config.maintenanceMode) {
      return MaintenanceScreen(message: config.maintenanceMessage);
    }

    return _BuildVersionGate(
      minSupportedBuild: config.minSupportedBuild,
      child: child,
    );
  }
}

class _BuildVersionGate extends StatelessWidget {
  const _BuildVersionGate({required this.minSupportedBuild, required this.child});
  final int minSupportedBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (ctx, snap) {
        if (!snap.hasData) return child; // never block on loading
        final currentBuild = int.tryParse(snap.data!.buildNumber) ?? 0;
        if (currentBuild >= minSupportedBuild) return child;
        return ForceUpdateScreen(currentBuild: currentBuild, requiredBuild: minSupportedBuild);
      },
    );
  }
}

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle_outlined, size: 64),
              const SizedBox(height: 16),
              const Text('Bakım modundayız', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 8),
              Text(
                message.isEmpty ? 'Kısa süre içinde döneceğiz.' : message,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.currentBuild,
    required this.requiredBuild,
  });
  final int currentBuild;
  final int requiredBuild;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update, size: 64),
              const SizedBox(height: 16),
              const Text('Güncelleme gerekli', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 8),
              Text('Build $currentBuild, en az $requiredBuild gerekiyor.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  // Open store URL — replace with your store IDs.
                  // launchUrl(Uri.parse('https://apps.apple.com/app/idXXXXX'));
                },
                child: const Text("Mağazadan Güncelle"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
