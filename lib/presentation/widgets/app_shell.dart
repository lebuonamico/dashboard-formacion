import 'package:app_finnegans/presentation/widgets/side_menu.dart';
import 'package:flutter/material.dart';

/// Marco de todas las pantallas autenticadas: el menú lateral queda fijo y
/// sólo cambia [child], la pantalla de la ruta actual. Así el menú no se
/// reconstruye al navegar y su animación no se corta.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
