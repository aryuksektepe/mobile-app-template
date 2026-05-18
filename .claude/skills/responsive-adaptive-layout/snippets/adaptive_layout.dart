import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Adaptive scaffold: same content, layout chosen from AVAILABLE SPACE.
/// Compact = single column + bottom nav; Medium/Expanded = nav rail + grid.
/// No OrientationBuilder, no isTablet(), no fixed sizes.
class AdaptiveHome extends StatelessWidget {
  const AdaptiveHome({super.key, required this.destinations, required this.body});
  final List<NavigationDestination> destinations;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        if (compact) {
          return Scaffold(
            body: SafeArea(child: body),
            bottomNavigationBar: NavigationBar(destinations: destinations),
          );
        }
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(icon: d.icon, label: Text(d.label)),
                  ],
                  selectedIndex: 0,
                ),
                const VerticalDivider(width: 1),
                // Don't gobble width on big screens — cap content width.
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Text that survives small screens AND large text scale: it reflows /
/// ellipsizes instead of overflowing a Row.
class SafeRowText extends StatelessWidget {
  const SafeRowText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Text(text, overflow: TextOverflow.ellipsis, softWrap: false),
      );
}
