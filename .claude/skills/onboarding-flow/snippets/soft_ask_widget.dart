// Soft-ask permission widget pattern. Use as an onboarding step OR as a
// modal at the right narrative moment.
//
// Critical: explain WHY before triggering OS prompt. Without this, denial
// rate is very high — and on iOS the OS prompt only shows ONCE.

import 'package:flutter/material.dart';

class SoftAskScreen extends StatelessWidget {
  const SoftAskScreen({
    super.key,
    required this.iconAsset,
    required this.title,
    required this.body,
    required this.allowLabel,
    required this.denyLabel,
    required this.onAllow,
    required this.onDeny,
  });

  final String iconAsset;     // Lottie or image
  final String title;
  final String body;
  final String allowLabel;
  final String denyLabel;
  final Future<void> Function() onAllow;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(iconAsset, height: 180),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(onPressed: onAllow, child: Text(allowLabel)),
              const SizedBox(height: 8),
              TextButton(onPressed: onDeny, child: Text(denyLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Example usage for notification permission:
///
/// SoftAskScreen(
///   iconAsset: 'assets/lottie/bell.json',
///   title: 'Bildirimleri açalım mı?',
///   body: 'Sipariş güncellemeleri ve önemli hatırlatmalar için '
///         'bildirim göndereceğiz. İstediğin zaman ayarlardan kapatabilirsin.',
///   allowLabel: 'İzin Ver',
///   denyLabel: 'Şimdi Değil',
///   onAllow: () async {
///     await ref.read(notificationServiceProvider).requestPermission();
///     ref.read(onboardingControllerProvider.notifier).nextStep();
///   },
///   onDeny: () => ref.read(onboardingControllerProvider.notifier).nextStep(),
/// )
