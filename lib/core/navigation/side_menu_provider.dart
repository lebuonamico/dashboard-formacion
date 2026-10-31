import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts expanded and is not persisted: reloading the page expands it again.
final sideMenuExpandedProvider = NotifierProvider<SideMenuNotifier, bool>(
  SideMenuNotifier.new,
);

class SideMenuNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
