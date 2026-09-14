import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Asegurate de importar tu widget principal / router
import 'package:app_finnegans/core/app_router.dart'; 

void main() {
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
