// size × textScale golden/overflow matrix. This is the test the pipeline
// lacked: one fixed-size, textScale=1.0 pump hides every responsive/dynamic-
// type break. Run for EVERY new screen and design-system component.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _sizes = <String, Size>{
  'small_320x640': Size(320, 640),   // small/old phone
  'modern_390x844': Size(390, 844),  // typical modern phone
  'tablet_768x1024': Size(768, 1024) // tablet / foldable open
};
const _scales = <double>[1.0, 1.3, 2.0]; // default, clamp, extreme a11y

void main() {
  for (final entry in _sizes.entries) {
    for (final scale in _scales) {
      testWidgets('SUT renders without overflow @ ${entry.key} x$scale',
          (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final overflows = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.exceptionAsString().contains('overflowed')) overflows.add(d);
          prev?.call(d);
        };

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: entry.value,
              textScaler: const TextScaler.linear(1).clamp(
                minScaleFactor: scale, maxScaleFactor: scale),
            ),
            child: const MaterialApp(home: SystemUnderTest()),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = prev;
        expect(overflows, isEmpty,
            reason: 'RenderFlex overflow @ ${entry.key} textScale=$scale');
        // Optional: also goldenFileComparator for visual regression per cell.
      });
    }
  }
}

class SystemUnderTest extends StatelessWidget {
  const SystemUnderTest({super.key});
  @override
  Widget build(BuildContext context) => const Placeholder(); // replace with screen
}
