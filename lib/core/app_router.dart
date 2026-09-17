import 'package:app_finnegans/presentation/area_detalle_screen.dart';
import 'package:app_finnegans/presentation/areas_screen.dart';
import 'package:app_finnegans/presentation/equipo.dart';
import 'package:app_finnegans/presentation/metricas_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/empleados_screen.dart';
import 'package:app_finnegans/presentation/dashboard_screen.dart';
import 'package:app_finnegans/presentation/login_screen.dart';
import 'package:app_finnegans/presentation/cursos_screen.dart';
import 'package:app_finnegans/presentation/configuracion_screen.dart';
import 'package:app_finnegans/presentation/cursada_screen.dart';
import 'package:app_finnegans/presentation/empleado_detalle_screen.dart';
import 'package:app_finnegans/presentation/equipos_screen.dart';
final appRouter = GoRouter(
  initialLocation: '/',

  routes: [
    GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: DashboardScreen()),
    ),
    GoRoute(
      path: '/empleados',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: EmpleadosScreen()),
    ),
    GoRoute(
      path: '/cursos',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: CursosScreen()),
    ),
    GoRoute(
      path: '/configuracion',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: ConfiguracionScreen()),
    ),
    GoRoute(
      path: '/cursadas',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: CursadasScreen()),
    ),
    GoRoute(
      path: '/empleados/:legajo',
      pageBuilder: (context, state) {
        final legajo = state.pathParameters['legajo']!;
        return NoTransitionPage(child: EmpleadoDetalleScreen(legajo: legajo));
      },
    ),
    GoRoute(
      path: '/metricas',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: MetricasScreen()),
    ),
    GoRoute(
      path: '/areas',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: AreasScreen()),
    ),
    GoRoute(
      path: '/areas/:area',
      pageBuilder: (context, state) {
        final area = state.pathParameters['area']!;
        return NoTransitionPage(child: AreaDetalleScreen(nombreArea: area));
      },
    ),
    GoRoute(
      path: '/areas/:area/equipos/:equipo',
      pageBuilder: (context, state) {
        final area = state.pathParameters['area']!;
        final equipo = state.pathParameters['equipo']!;
        return NoTransitionPage(
          child: EquipoScreen(area: area, equipo: equipo),
        );
      },
    ),
    GoRoute(
      path: '/equipos',
      pageBuilder: (context, state) =>
          const NoTransitionPage(child: EquiposScreen()),
    ),
  ],
);
