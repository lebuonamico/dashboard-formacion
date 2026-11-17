import 'package:flutter/widgets.dart';

/// Published by the shell. Every screen has its own `Scaffold`, so the top bar
/// cannot reach the shell's drawer with `Scaffold.of`: it asks this scope.
class ModalNavigationScope extends InheritedWidget {
  /// Opens the modal menu; `null` while the menu is fixed at the side.
  final VoidCallback? openMenu;

  const ModalNavigationScope({
    super.key,
    required this.openMenu,
    required super.child,
  });

  /// How to open the modal menu, or `null` when the menu is fixed at the side
  /// (desktop) or there is no shell (a screen mounted alone in a test).
  static VoidCallback? maybeOpenMenuOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ModalNavigationScope>()
      ?.openMenu;

  @override
  bool updateShouldNotify(ModalNavigationScope oldWidget) =>
      openMenu != oldWidget.openMenu;
}
