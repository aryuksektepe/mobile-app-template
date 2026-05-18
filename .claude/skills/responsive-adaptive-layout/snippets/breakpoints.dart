import 'package:flutter/widgets.dart';

/// Material 3 window size classes — the breakpoint contract for the whole app.
/// https://m3.material.io/foundations/layout/applying-layout/window-size-classes
enum WindowSize { compact, medium, expanded }

extension WindowSizeX on BuildContext {
  /// Decide from AVAILABLE WIDTH (MediaQuery.sizeOf), never device type or
  /// orientation. Prefer LayoutBuilder constraints inside flexible subtrees.
  WindowSize get windowSize {
    final w = MediaQuery.sizeOf(this).width;
    if (w < 600) return WindowSize.compact;   // phones (most)
    if (w < 840) return WindowSize.medium;    // large phone landscape / small tablet
    return WindowSize.expanded;               // tablet / foldable open / desktop
  }

  bool get isCompact => windowSize == WindowSize.compact;
}

/// Pick a value per window size without branching everywhere.
T responsive<T>(
  BuildContext context, {
  required T compact,
  T? medium,
  T? expanded,
}) {
  switch (context.windowSize) {
    case WindowSize.compact:
      return compact;
    case WindowSize.medium:
      return medium ?? compact;
    case WindowSize.expanded:
      return expanded ?? medium ?? compact;
  }
}
