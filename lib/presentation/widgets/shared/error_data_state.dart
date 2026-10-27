import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Explica en lenguaje simple por qué no se pudieron cargar los datos. El
/// detalle técnico queda en la consola, no en pantalla.
String mensajeErrorCarga(Object error) {
  if (error is FormatException) return error.message;
  if (error is PostgrestException) {
    final codigo = error.code ?? '';
    // Columna o tabla inexistente: la base y la aplicación no coinciden.
    if (const {'42703', '42P01', 'PGRST204', 'PGRST205'}.contains(codigo)) {
      return 'La base de datos no coincide con esta versión de la aplicación. '
          'Recargá la página y, si sigue igual, avisá al administrador.';
    }
    if (codigo == '42501' || codigo == 'PGRST301') {
      return 'No tenés permisos para ver esta información.';
    }
  }
  if (error is AuthException) {
    return 'Tu sesión venció. Volvé a iniciar sesión.';
  }
  final texto = error.toString();
  if (texto.contains('SocketException') ||
      texto.contains('ClientException') ||
      texto.contains('Failed to fetch') ||
      texto.contains('TimeoutException')) {
    return 'No se pudo conectar con el servidor. Revisá tu conexión y '
        'recargá la página.';
  }
  return 'Ocurrió un error inesperado. Recargá la página y, si sigue igual, '
      'avisá al administrador.';
}

class ErrorDataState extends StatelessWidget {
  final String title;
  final Object error;
  final bool compact;

  const ErrorDataState({
    super.key,
    required this.title,
    required this.error,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('$title: $error');
    final cs = context.colorScheme;
    return Center(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 640),
        padding: EdgeInsets.symmetric(
          vertical: compact ? 24 : 56,
          horizontal: 24,
        ),
        decoration: context.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 34, color: cs.error),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mensajeErrorCarga(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
