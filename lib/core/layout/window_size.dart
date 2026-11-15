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

  /// Shorter than this (Material's compact height), a wide window is a phone
  /// on its side.
  static const double expandedMinHeight = 480;

  static WindowSize fromWidth(double width) {
    if (width < mediumMinWidth) return WindowSize.compact;
    if (width < expandedMinWidth) return WindowSize.medium;
    return WindowSize.expanded;
  }

  /// Like [fromWidth], but a wide and short window (a phone in landscape,
  /// about 844×390) is [medium]: the fixed menu would take a third of the
  /// width, and the tables that fill the height would get no room.
  static WindowSize fromSize(Size size) {
    final byWidth = fromWidth(size.width);
    if (byWidth == WindowSize.expanded && size.height < expandedMinHeight) {
      return WindowSize.medium;
    }
    return byWidth;
  }

  /// Below [expandedMinWidth] the drawer opens as a modal from the top bar.
  bool get usesModalNavigation => this != WindowSize.expanded;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize => WindowSize.fromSize(MediaQuery.sizeOf(this));

  bool get usesModalNavigation => windowSize.usesModalNavigation;

  /// A dialog's margins: on a phone the default 40 px leave little room.
  /// `null` keeps the default.
  EdgeInsets? get dialogInsetPadding => windowSize == WindowSize.compact
      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
      : null;
}
