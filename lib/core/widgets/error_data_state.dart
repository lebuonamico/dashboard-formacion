import 'package:app_finnegans/core/data/data_error.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Explains in plain words why the data could not load. The technical
/// detail stays out of the screen.
String loadErrorMessage(Object error) => switch (classifyDataError(error)) {
  DataErrorKind.invalidData => (error as FormatException).message,
  DataErrorKind.schemaMismatch =>
    'La base de datos no coincide con esta versión de la aplicación. '
        'Recargá la página y, si sigue igual, avisá al administrador.',
  DataErrorKind.forbidden => 'No tenés permisos para ver esta información.',
  DataErrorKind.sessionExpired => 'Tu sesión venció. Volvé a iniciar sesión.',
  DataErrorKind.network =>
    'No se pudo conectar con el servidor. Revisá tu conexión y '
        'recargá la página.',
  DataErrorKind.unknown =>
    'Ocurrió un error inesperado. Recargá la página y, si sigue igual, '
        'avisá al administrador.',
};

class ErrorDataState extends StatelessWidget {
  final String title;
  final Object error;
  final bool compact;
  final VoidCallback? onRetry;

  const ErrorDataState({
    super.key,
    required this.title,
    required this.error,
    this.compact = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
              loadErrorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
