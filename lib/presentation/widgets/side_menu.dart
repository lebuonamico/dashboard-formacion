import 'package:app_finnegans/presentation/widgets/reloj_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {

    final currentRoute = GoRouterState.of(context).uri.toString();

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Logo
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D53C3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finnegans',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0D53C3),
                      ),
                    ),
                    Text(
                      'Portal de formación interna',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Items de navegación
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _MenuItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Inicio',
                  isSelected: currentRoute.startsWith('/dashboard'),
                  onTap: () {
                    context.push('/dashboard'); // Navega a la pantalla de dashboard
                  },
                ),
                _MenuItem(
                  icon: Icons.account_tree_outlined,
                  label: 'Áreas',
                  isSelected: currentRoute.startsWith('/areas'),
                  onTap: () {
                    context.push('/areas'); // Navega a la pantalla de áreas
                  },
                ),
                _MenuItem(
                  icon: Icons.group_work,
                  label: 'Equipos',
                  isSelected: currentRoute.startsWith('/equipos'),
                  onTap: () {
                    context.push('/equipos'); // Navega a la pantalla de equipos
                  },
                ),
                _MenuItem(
                  icon: Icons.people_outline,
                  label: 'Empleados',
                  isSelected: currentRoute.startsWith('/empleados'),
                  onTap: () {
                    context.push('/empleados'); // Navega a la pantalla de empleados
                  },
                ),
                
                _MenuItem(
                  icon: Icons.school_outlined,
                  label: 'Cursos',
                  isSelected: currentRoute.startsWith('/cursos'),
                  onTap: () {
                    context.push('/cursos'); // Navega a la pantalla de cursos
                  },
                ),
                _MenuItem(
                  icon: Icons.assignment_outlined,
                  label: 'Cursadas',
                  isSelected: currentRoute.startsWith('/cursadas'),
                  onTap: () {
                    context.push('/cursadas'); // Navega a la pantalla de cursadas
                  },
                ),
                _MenuItem(
                  icon: Icons.analytics_outlined,
                  label: 'Métricas',
                  isSelected: currentRoute.startsWith('/metricas'),
                  onTap: () {
                    context.push('/metricas'); // Navega a la pantalla de métricas
                  },
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Configuración',
                  isSelected: currentRoute.startsWith('/configuracion'),
                  onTap: () {
                    context.push('/configuracion'); // Navega a la pantalla de configuración
                  },
                ),
                
              ],
            ),
          ),
          // Reloj
          const ClockWidget(),
          // Logout
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _MenuItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              isSelected: false,
              textColor: const Color(0xFFEF4444),
              iconColor: const Color(0xFFEF4444),
              onTap: () {
                context.go('/'); // Navega a la pantalla de login
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor = isSelected ? const Color(0xFF0D53C3) : const Color(0xFF64748B);
    final bgColor = isSelected ? const Color(0xFF0D53C3).withValues(alpha: 0.08) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: iconColor ?? defaultColor,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: textColor ?? (isSelected ? const Color(0xFF0D53C3) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}