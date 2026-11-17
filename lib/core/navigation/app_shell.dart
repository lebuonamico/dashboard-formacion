import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/navigation/app_navigation_drawer.dart';
import 'package:app_finnegans/core/navigation/modal_navigation_scope.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_chat.dart';
import 'package:flutter/material.dart';

/// Frame of every authenticated screen. From 840 px the side menu is fixed at
/// the left; below, it is a modal drawer that the top bar's menu button opens.
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final modal = context.usesModalNavigation;
    return Scaffold(
      key: _scaffoldKey,
      drawer: modal ? const ModalNavigationDrawer() : null,
      body: SafeArea(
        child: Stack(
          children: [
            // The same tree at every width: crossing 840 px only adds or
            // removes the fixed menu, and the screen keeps its state.
            ModalNavigationScope(
              openMenu: modal ? _openMenu : null,
              child: Row(
                children: [
                  if (!modal) const AppNavigationDrawer(),
                  Expanded(child: widget.child),
                ],
              ),
            ),
            const Positioned.fill(child: AssistantChat()),
          ],
        ),
      ),
    );
  }
}
