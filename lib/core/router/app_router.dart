import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/areas/presentation/area_detail_screen.dart';
import 'package:app_finnegans/features/areas/presentation/areas_screen.dart';
import 'package:app_finnegans/features/teams/presentation/team_detail_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/features/employees/presentation/employees_screen.dart';
import 'package:app_finnegans/features/dashboard/presentation/dashboard_screen.dart';
import 'package:app_finnegans/features/auth/presentation/login_screen.dart';
import 'package:app_finnegans/features/courses/presentation/courses_screen.dart';
import 'package:app_finnegans/features/settings/presentation/settings_screen.dart';
import 'package:app_finnegans/features/time_entries/presentation/time_entries_screen.dart';
import 'package:app_finnegans/features/certifications/presentation/certifications_screen.dart';
import 'package:app_finnegans/features/employees/presentation/employee_detail_screen.dart';
import 'package:app_finnegans/features/teams/presentation/teams_screen.dart';
import 'package:app_finnegans/features/admin/presentation/admin_screen.dart';
import 'package:app_finnegans/core/widgets/app_shell.dart';

/// Duración del fundido al cambiar de pantalla.
const _fadeDuration = Duration(milliseconds: 200);

/// Página que entra con un fundido. Como la nueva se pinta sobre la anterior
/// (ambas con fondo opaco), se ve como un fundido cruzado.
CustomTransitionPage<void> _withFade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _fadeDuration,
    reverseTransitionDuration: _fadeDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

GoRouter createAppRouter(AuthController auth) => GoRouter(
  initialLocation: '/',
  refreshListenable: auth,
  redirect: (context, state) => auth.redirect(state.uri.path),

  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _withFade(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _withFade(state, const LoginScreen()),
    ),
    // Todas las pantallas autenticadas comparten el menú lateral: queda fijo y
    // sólo cambia el contenido.
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              _withFade(state, const DashboardScreen()),
        ),
        GoRoute(
          path: '/empleados',
          pageBuilder: (context, state) =>
              _withFade(state, const EmployeesScreen()),
        ),
        GoRoute(
          path: '/cursos',
          pageBuilder: (context, state) =>
              _withFade(state, const CoursesScreen()),
        ),
        GoRoute(
          path: '/configuracion',
          pageBuilder: (context, state) =>
              _withFade(state, const SettingsScreen()),
        ),
        GoRoute(
          path: '/cursadas',
          pageBuilder: (context, state) =>
              _withFade(state, const TimeEntriesScreen()),
        ),
        GoRoute(
          path: '/certificaciones',
          pageBuilder: (context, state) =>
              _withFade(state, const CertificationsScreen()),
        ),
        GoRoute(
          path: '/empleados/:legajo',
          pageBuilder: (context, state) {
            final employeeId = state.pathParameters['legajo']!;
            return _withFade(
              state,
              EmployeeDetailScreen(employeeId: employeeId),
            );
          },
        ),

        GoRoute(
          path: '/areas',
          pageBuilder: (context, state) =>
              _withFade(state, const AreasScreen()),
        ),
        GoRoute(
          path: '/areas/:area',
          pageBuilder: (context, state) {
            final area = state.pathParameters['area']!;
            return _withFade(state, AreaDetailScreen(areaName: area));
          },
        ),
        GoRoute(
          path: '/areas/:area/equipos/:equipo',
          pageBuilder: (context, state) {
            final area = state.pathParameters['area']!;
            final team = state.pathParameters['equipo']!;
            return _withFade(state, TeamDetailScreen(area: area, team: team));
          },
        ),
        GoRoute(
          path: '/equipos',
          pageBuilder: (context, state) =>
              _withFade(state, const TeamsScreen()),
        ),
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) =>
              _withFade(state, const AdminScreen()),
        ),
      ],
    ),
  ],
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider.notifier);
  final router = createAppRouter(auth);
  ref.onDispose(router.dispose);
  return router;
});
