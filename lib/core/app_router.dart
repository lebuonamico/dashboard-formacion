import 'package:app_finnegans/presentation/metricas_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/presentation/empleados_screen.dart';
import 'package:app_finnegans/presentation/dashboard_screen.dart';
import 'package:app_finnegans/presentation/login_screen.dart';
import 'package:app_finnegans/presentation/cursos_screen.dart';
import 'package:app_finnegans/presentation/configuracion_screen.dart';
import 'package:app_finnegans/presentation/cursada_screen.dart';
import 'package:app_finnegans/presentation/empleado_detalle_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',

  routes: [

    GoRoute(path: '/',          builder: (context, state) => const LoginScreen(),),
    GoRoute(path: '/dashboard', pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen(),),),
    GoRoute(path: '/empleados',  pageBuilder: (context, state) => const NoTransitionPage(child: EmpleadosScreen(),),),
    GoRoute(path: '/cursos',     pageBuilder: (context, state) => const NoTransitionPage(child: CursosScreen(),),),
    GoRoute(path: '/configuracion', pageBuilder: (context, state) => const NoTransitionPage(child: ConfiguracionScreen(),),),
    GoRoute(path: '/cursadas', pageBuilder: (context, state) => const NoTransitionPage(child: CursadasScreen(),),),
    GoRoute(path: '/empleados/:legajo', pageBuilder: (context, state) 
    {
      final legajo = state.pathParameters['legajo']!;
        return NoTransitionPage(
          child: EmpleadoDetalleScreen(legajo: legajo),
        );
    },),
    GoRoute(path: '/metricas', pageBuilder: (context, state) => const NoTransitionPage(child: MetricasScreen(),),),
  ],);