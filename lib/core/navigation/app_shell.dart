import 'package:app_finnegans/core/navigation/app_navigation_drawer.dart';
import 'package:app_finnegans/features/assistant/presentation/widgets/assistant_chat.dart';
import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                const AppNavigationDrawer(),
                Expanded(child: child),
              ],
            ),
            const Positioned.fill(child: AssistantChat()),
          ],
        ),
      ),
    );
  }
}
