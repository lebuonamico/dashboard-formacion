import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/area_detalle_screen.dart';
import 'package:app_finnegans/presentation/areas_screen.dart';
import 'package:app_finnegans/presentation/team_screen.dart';
import 'package:app_finnegans/presentation/metricas_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/empleados_screen.dart';
import 'package:app_finnegans/presentation/dashboard_screen.dart';
import 'package:app_finnegans/presentation/login_screen.dart';
import 'package:app_finnegans/presentation/cursos_screen.dart';
import 'package:app_finnegans/presentation/configuracion_screen.dart';
import 'package:app_finnegans/presentation/cursada_screen.dart';
import 'package:app_finnegans/presentation/certificacion_screen.dart';
import 'package:app_finnegans/presentation/empleado_detalle_screen.dart';
import 'package:app_finnegans/presentation/teams_screen.dart';
import 'package:app_finnegans/presentation/admin_screen.dart';
import 'package:app_finnegans/presentation/widgets/app_shell.dart';

/// Duración del fundido al cambiar de pantalla.
const _duracionFundido = Duration(milliseconds: 200);

/// Página que entra con un fundido. Como la nueva se pinta sobre la anterior
/// (ambas con fondo opaco), se ve como un fundido cruzado.
CustomTransitionPage<void> _conFundido(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _duracionFundido,
    reverseTransitionDuration: _duracionFundido,
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
      pageBuilder: (context, state) => _conFundido(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _conFundido(state, const LoginScreen()),
    ),
    // Todas las pantallas autenticadas comparten el menú lateral: queda fijo y
    // sólo cambia el contenido.
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              _conFundido(state, const DashboardScreen()),
        ),
        GoRoute(
          path: '/empleados',
          pageBuilder: (context, state) =>
              _conFundido(state, const EmpleadosScreen()),
        ),
        GoRoute(
          path: '/cursos',
          pageBuilder: (context, state) =>
              _conFundido(state, const CursosScreen()),
        ),
        GoRoute(
          path: '/configuracion',
          pageBuilder: (context, state) =>
              _conFundido(state, const ConfiguracionScreen()),
        ),
        GoRoute(
          path: '/cursadas',
          pageBuilder: (context, state) =>
              _conFundido(state, const CursadasScreen()),
        ),
        GoRoute(
          path: '/certificaciones',
          pageBuilder: (context, state) =>
              _conFundido(state, const CertificacionScreen()),
        ),
        GoRoute(
          path: '/empleados/:legajo',
          pageBuilder: (context, state) {
            final legajo = state.pathParameters['legajo']!;
            return _conFundido(state, EmpleadoDetalleScreen(legajo: legajo));
          },
        ),

        GoRoute(
          path: '/metricas',
          pageBuilder: (context, state) =>
              _conFundido(state, const MetricasScreen()),
        ),
        GoRoute(
          path: '/areas',
          pageBuilder: (context, state) =>
              _conFundido(state, const AreasScreen()),
        ),
        GoRoute(
          path: '/areas/:area',
          pageBuilder: (context, state) {
            final area = state.pathParameters['area']!;
            return _conFundido(state, AreaDetalleScreen(nombreArea: area));
          },
        ),
        GoRoute(
          path: '/areas/:area/equipos/:equipo',
          pageBuilder: (context, state) {
            final area = state.pathParameters['area']!;
            final equipo = state.pathParameters['equipo']!;
            return _conFundido(state, EquipoScreen(area: area, equipo: equipo));
          },
        ),
        GoRoute(
          path: '/equipos',
          pageBuilder: (context, state) =>
              _conFundido(state, const EquiposScreen()),
        ),
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) =>
              _conFundido(state, const AdminScreen()),
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
