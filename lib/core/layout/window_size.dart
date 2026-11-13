import 'package:flutter/widgets.dart';

/// Material 3 window size classes. The shell and the structure of each screen
/// decide by the window width; components keep deciding by their own space
/// with `LayoutBuilder`.
enum WindowSize {
  /// Phone: below [WindowSize.mediumMinWidth].
  compact,

  /// Portrait tablet or small window: modal navigation and card lists.
  medium,

  /// From [WindowSize.expandedMinWidth]: the desktop layout.
  expanded;

  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;

  static WindowSize fromWidth(double width) {
    if (width < mediumMinWidth) return WindowSize.compact;
    if (width < expandedMinWidth) return WindowSize.medium;
    return WindowSize.expanded;
  }

  /// Below [expandedMinWidth] the drawer opens as a modal from the top bar.
  bool get usesModalNavigation => this != WindowSize.expanded;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize =>
      WindowSize.fromWidth(MediaQuery.sizeOf(this).width);

  bool get usesModalNavigation => windowSize.usesModalNavigation;
}
