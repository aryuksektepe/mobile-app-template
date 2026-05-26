// Pre-prompt education screen. Shows BEFORE the system ATT prompt.
// Proven to lift opt-in by 20-40pp vs. direct system prompt.
//
// Apple Guideline 5.1.2(i) MUST-NOTS for this screen:
//  - Don't mimic system UI (no black bar, no system icons).
//  - Don't imply consent is required to use the app.
//  - Don't gate features behind the ATT response.
//  - Don't pre-check "Allow" by visual emphasis only — neutral framing.

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'att_service.dart';

class AttPrePrompt extends ConsumerWidget {
  const AttPrePrompt({super.key, required this.onDone});

  /// Called with the resolved status after the system prompt.
  final void Function(TrackingStatus) onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'Size daha alakalı içerik için',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  // NEUTRAL framing — list value, not pressure. Match Privacy Manifest
                  // NSPrivacyTrackingDomains list. Update copy with marketing/legal.
                  const Text(
                    'Bir sonraki adımda Apple sana bir izin penceresi gösterecek. '
                    '"İzin Ver"i seçersen, içerikleri ilgi alanlarına göre öneririz '
                    've yaptığımız kampanyaların ne kadar işe yaradığını ölçeriz.\n\n'
                    'Bu izin uygulamanın çalışması için gerekli değil — '
                    'reddedersen de tüm özellikler kullanılabilir.',
                  ),
                ],
              ),
              // Single CTA — taps the system prompt. No "skip" or "ask later"
              // (those are anti-patterns: leave that choice to the system prompt).
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final status = await AttService.instance.request();
                    ref.read(attStatusProvider.notifier).state = status;
                    if (context.mounted) onDone(status);
                  },
                  child: const Text('Devam et'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
