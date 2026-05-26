// OTP entry screen — 6-digit pinput with paste, 60s resend countdown,
// auto-fill from Android SMS auto-retrieval, success redirect.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'phone_auth_service.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});
  final String phoneNumber;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _ctl = TextEditingController();
  Timer? _resendTimer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    setState(() => _secondsLeft = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 0) { t.cancel(); return; }
      setState(() => _secondsLeft--);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Auto-fill on Android auto-retrieval
    ref.listen(phoneAuthServiceProvider, (prev, next) {
      if (next.autoRetrievedCode != null && _ctl.text != next.autoRetrievedCode) {
        _ctl.text = next.autoRetrievedCode!;
      }
      if (next.step == PhoneAuthStep.verified) {
        // Router will pick up auth state — pop or redirect.
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      if (next.step == PhoneAuthStep.failed && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    final state = ref.watch(phoneAuthServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kodu doğrula')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.phoneNumber} numarasına gönderilen 6 haneli kodu gir.'),
            const SizedBox(height: 32),
            Pinput(
              controller: _ctl,
              length: 6,
              autofocus: true,
              keyboardType: TextInputType.number,
              onCompleted: (code) {
                ref.read(phoneAuthServiceProvider.notifier).verifyCode(code);
              },
            ),
            const Spacer(),
            Center(
              child: _secondsLeft > 0
                  ? Text('Yeniden gönder ($_secondsLeft sn)')
                  : TextButton(
                      onPressed: () async {
                        await ref.read(phoneAuthServiceProvider.notifier).sendCode(widget.phoneNumber);
                        _startResendCountdown();
                      },
                      child: const Text('Yeniden gönder'),
                    ),
            ),
            const SizedBox(height: 16),
            if (state.step == PhoneAuthStep.verifying)
              const Center(child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
