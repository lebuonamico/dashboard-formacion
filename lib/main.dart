import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Asegurate de importar tu widget principal / router
import 'package:app_finnegans/core/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(
    // Envolver aquí con ProviderScope:
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'App Finnegans',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
