import 'package:app_finnegans/core/app_router.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/tema_provider.dart';
import 'package:app_finnegans/presentation/widgets/transicion_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  final appearance = await ThemeModeController.readSaved();
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(() => ThemeModeController(appearance)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'App Finnegans',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      // El cambio de tema lo anima TransicionTema con un fundido; interpolar
      // el ThemeData reconstruiría toda la app en cada frame.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => ThemeTransition(child: child!),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
