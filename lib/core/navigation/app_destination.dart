import 'package:flutter/material.dart';

enum DestinationAccess { everyone, managers, exceptTeamLeads }

class AppDestination {
  final String section;
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final DestinationAccess access;

  const AppDestination({
    required this.section,
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.access = DestinationAccess.everyone,
  });
}

const appDestinations = [
  AppDestination(
    section: 'dashboard',
    path: '/dashboard',
    label: 'Inicio',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  AppDestination(
    section: 'areas',
    path: '/areas',
    label: 'Áreas',
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree,
    access: DestinationAccess.exceptTeamLeads,
  ),
  AppDestination(
    section: 'equipos',
    path: '/equipos',
    label: 'Equipos',
    icon: Icons.group_work_outlined,
    selectedIcon: Icons.group_work,
  ),
  AppDestination(
    section: 'empleados',
    path: '/empleados',
    label: 'Empleados',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  AppDestination(
    section: 'cursos',
    path: '/cursos',
    label: 'Cursos',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
  ),
  AppDestination(
    section: 'cursadas',
    path: '/cursadas',
    label: 'Carga de horas CRM',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
  ),
  AppDestination(
    section: 'certificaciones',
    path: '/certificaciones',
    label: 'Certificaciones LMS',
    icon: Icons.verified_outlined,
    selectedIcon: Icons.verified,
  ),
  AppDestination(
    section: 'configuracion',
    path: '/configuracion',
    label: 'Configuración',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    access: DestinationAccess.managers,
  ),
  AppDestination(
    section: 'admin',
    path: '/admin',
    label: 'Panel de administrador',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    access: DestinationAccess.managers,
  ),
];

List<AppDestination> visibleDestinations({
  required bool canManage,
  required bool isTeamLead,
}) => appDestinations
    .where(
      (destination) => switch (destination.access) {
        DestinationAccess.everyone => true,
        DestinationAccess.managers => canManage,
        DestinationAccess.exceptTeamLeads => !isTeamLead,
      },
    )
    .toList();

/// A detail screen opened from another section highlights that section,
/// which travels in the `origen` query parameter.
int? selectedDestinationIndex(Uri uri, List<AppDestination> destinations) {
  final origin = uri.queryParameters['origen'];
  final byOrigin = destinations.indexWhere(
    (destination) => destination.section == origin,
  );
  if (byOrigin != -1) return byOrigin;
  final byPath = destinations.indexWhere(
    (destination) => uri.path.startsWith(destination.path),
  );
  return byPath == -1 ? null : byPath;
}
