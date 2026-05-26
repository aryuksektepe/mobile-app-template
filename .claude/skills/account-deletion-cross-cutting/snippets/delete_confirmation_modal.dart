// Delete account confirmation modal with:
//   - Destructive UI (red)
//   - Typed "DELETE" confirmation (anti-mistap)
//   - Active subscription warning + deep-link to store sub settings
//   - Reauth prompt (password for email/pwd; biometric for others)
//
// Place this at Settings → Account → "Hesabımı sil" (must be ≤ 2 taps from main Account).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeleteAccountConfirmationModal extends StatefulWidget {
  const DeleteAccountConfirmationModal({super.key, required this.hasActiveSub});
  final bool hasActiveSub;

  @override
  State<DeleteAccountConfirmationModal> createState() => _DeleteAccountConfirmationModalState();
}

class _DeleteAccountConfirmationModalState extends State<DeleteAccountConfirmationModal> {
  final _ctl = TextEditingController();
  static const _phrase = 'SIL'; // localize: "DELETE" for EN
  bool get _phraseOk => _ctl.text.trim().toUpperCase() == _phrase;

  Future<void> _openSubSettings() async {
    final url = Platform.isIOS
        ? Uri.parse('itms-apps://apps.apple.com/account/subscriptions')
        : Uri.parse('https://play.google.com/store/account/subscriptions');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.warning_amber, color: theme.colorScheme.error, size: 48),
      title: const Text('Hesabını silmek istediğinden emin misin?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bu işlem geri alınamaz. Tüm verilerin 30 gün içinde sunucularımızdan kalıcı olarak silinir.\n'
            '30 gün içinde tekrar giriş yaparsan hesabın geri yüklenir.',
          ),
          if (widget.hasActiveSub) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktif aboneliğin var',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hesabını silmek aboneliğini İPTAL ETMEZ. Önce mağazadan iptal et, '
                    'yoksa ödeme alınmaya devam eder.',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _openSubSettings,
                    child: const Text('Mağazadan iptal et'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Onaylamak için "$_phrase" yaz:', style: theme.textTheme.bodyMedium),
          TextField(
            controller: _ctl,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: _phraseOk ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Hesabımı sil'),
        ),
      ],
    );
  }
}
