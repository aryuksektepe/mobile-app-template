// ReviewPromptService — gated rating prompt.
//
// Usage:
//   // From positive-moment handler (lesson complete, purchase success, etc.):
//   await ref.read(reviewPromptServiceProvider).recordHappyMoment();
//   // Then opportunistically:
//   await ref.read(reviewPromptServiceProvider).maybePrompt();

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewPromptService {
  static const _kHappyCountKey = 'review_happy_count';
  static const _kLastPromptKey = 'review_last_prompt_ms';
  static const _kInstalledAtKey = 'app_installed_at_ms';

  static const _minHappyMoments = 3;
  static const _minInstallDays = 7;
  static const _cooldownDays = 90;

  final InAppReview _api = InAppReview.instance;

  Future<void> recordHappyMoment() async {
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getInt(_kHappyCountKey) ?? 0;
    await prefs.setInt(_kHappyCountKey, c + 1);
    // Capture install time once
    if (prefs.getInt(_kInstalledAtKey) == null) {
      await prefs.setInt(_kInstalledAtKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Returns true if a prompt was shown (or fallback CTA fired).
  Future<bool> maybePrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // Gate 1: happy-moment threshold
    final happy = prefs.getInt(_kHappyCountKey) ?? 0;
    if (happy < _minHappyMoments) return false;

    // Gate 2: install age
    final installedAt = prefs.getInt(_kInstalledAtKey) ?? DateTime.now().millisecondsSinceEpoch;
    final ageDays = (DateTime.now().millisecondsSinceEpoch - installedAt) / (1000 * 60 * 60 * 24);
    if (ageDays < _minInstallDays) return false;

    // Gate 3: cooldown since last prompt
    final lastPromptMs = prefs.getInt(_kLastPromptKey) ?? 0;
    final daysSincePrompt = (DateTime.now().millisecondsSinceEpoch - lastPromptMs) / (1000 * 60 * 60 * 24);
    if (lastPromptMs != 0 && daysSincePrompt < _cooldownDays) return false;

    // Try OS-native prompt
    final isAvailable = await _api.isAvailable();
    if (isAvailable) {
      await _api.requestReview();
      await prefs.setInt(_kLastPromptKey, DateTime.now().millisecondsSinceEpoch);
      // Reset happy counter — don't pile up another prompt soon
      await prefs.setInt(_kHappyCountKey, 0);
      return true;
    }

    // Fallback: deep link to store listing (Huawei / Amazon / iOS sandbox)
    try {
      await _api.openStoreListing();
      await prefs.setInt(_kLastPromptKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(_kHappyCountKey, 0);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Manual "Rate us" tap from Settings — always opens store listing, no gates.
  Future<void> openStoreListing() => _api.openStoreListing();
}

final reviewPromptServiceProvider = Provider<ReviewPromptService>((_) => ReviewPromptService());
