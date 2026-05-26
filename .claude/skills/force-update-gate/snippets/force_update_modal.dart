// Force-update modal — NO dismiss, single "Update now" CTA → store deep link.
// Soft-update banner is a separate, dismissable widget (similar but with "Later").

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_gate.dart';

const _kAppleAppId = '1234567890';                    // REPLACE
const _kAndroidPackage = 'com.yourcompany.yourapp';   // REPLACE

class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _openStore() async {
    final url = Platform.isIOS
        ? Uri.parse('itms-apps://apps.apple.com/app/id$_kAppleAppId')
        : Uri.parse('market://details?id=$_kAndroidPackage');
    final fallback = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/app/id$_kAppleAppId')
        : Uri.parse('https://play.google.com/store/apps/details?id=$_kAndroidPackage');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateAsync = ref.watch(updateGateProvider);
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,  // back-button can't dismiss
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.system_update, size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  'Yeni sürüm gerekli',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  gateAsync.valueOrNull?.message ??
                      'Uygulamayı kullanmaya devam etmek için en son sürüme güncelle.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _openStore,
                    child: const Text('Şimdi güncelle'),
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
