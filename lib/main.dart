import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/core/supabase_config.dart';
// Asegurate de importar tu widget principal / router
import 'package:app_finnegans/core/app_router.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(
    // Envolver aquí con ProviderScope:
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App Finnegans',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter, // Tu configuración de go_router
    );
  }
}
