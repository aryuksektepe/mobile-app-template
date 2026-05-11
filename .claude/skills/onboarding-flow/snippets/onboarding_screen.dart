// Onboarding PageView. 3-5 pages max (research: 21-72% drop-off above 5).
// Persistent Skip + dynamic Next/Get-Started CTA. Smooth page indicator.
// Semantic labels for accessibility.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'onboarding_controller.dart';

class OnboardingPage {
  const OnboardingPage({
    required this.title,
    required this.body,
    required this.assetPath,   // Lottie or image — keep <500KB each
  });

  final String title;
  final String body;
  final String assetPath;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.pages, required this.onDone});

  final List<OnboardingPage> pages;
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    final initialStep = ref.read(onboardingControllerProvider).valueOrNull?.step ?? 0;
    _ctrl = PageController(initialPage: initialStep.clamp(0, widget.pages.length - 1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    final isLast = _ctrl.page?.round() == widget.pages.length - 1;
    if (isLast) {
      await ref.read(onboardingControllerProvider.notifier).complete();
      widget.onDone();
      return;
    }
    await ref.read(onboardingControllerProvider.notifier).nextStep();
    await _ctrl.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onSkip() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — visible on every page (accessibility + UX best practice).
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: TextButton(
                onPressed: _onSkip,
                child: const Text('Atla'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: widget.pages.length,
                itemBuilder: (ctx, i) => _OnboardingPageView(page: widget.pages[i], index: i, total: widget.pages.length),
              ),
            ),
            const SizedBox(height: 16),
            SmoothPageIndicator(
              controller: _ctrl,
              count: widget.pages.length,
              effect: const WormEffect(dotHeight: 8, dotWidth: 8),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (ctx, _) {
                    final isLast = (_ctrl.hasClients ? _ctrl.page?.round() : 0) ==
                        widget.pages.length - 1;
                    return FilledButton(
                      onPressed: _onNext,
                      child: Text(isLast ? 'Başlayalım' : 'Devam'),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({
    required this.page,
    required this.index,
    required this.total,
  });

  final OnboardingPage page;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tanıtım ekranı ${index + 1} / $total',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use Lottie.asset(page.assetPath) if Lottie file
            Image.asset(page.assetPath, height: 240),
            const SizedBox(height: 32),
            Text(
              page.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              page.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
