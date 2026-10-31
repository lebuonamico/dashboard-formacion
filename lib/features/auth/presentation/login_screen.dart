import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/auth/data/access_rejection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _rejectionMessage;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.hasValidSession && !auth.isValidatingAuthorization) {
      // Read on arrival or after logout when login is already mounted.
      final pendingMessage = readAccessRejectionMessage();
      if (pendingMessage != null) {
        _rejectionMessage = pendingMessage;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Consume only after this screen has actually displayed the text.
          if (mounted && !ref.read(authControllerProvider).hasValidSession) {
            consumeAccessRejectionMessage();
          }
        });
      }
    }
    final loginMessage = _rejectionMessage ?? auth.error;
    final cs = context.colorScheme;
    final colors = context.colors;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card central
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono de cabecera
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo_finnegans.png',
                        width: 52,
                        height: 52,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Títulos de marca
                    Text(
                      'Finnegans',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plataforma de control de formación interna',
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Bienvenida y descripción
                    Text(
                      'Bienvenido de nuevo',
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Inicia sesión con tu cuenta corporativa\npara acceder al sistema.',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Botón Google Sign-In
                    OutlinedButton(
                      onPressed:
                          auth.isSigningIn || auth.isValidatingAuthorization
                          ? null
                          : () async {
                              if (!auth.enabled) {
                                context.go('/dashboard');
                                return;
                              }
                              clearAccessRejection();
                              setState(() => _rejectionMessage = null);
                              await auth.signInWithGoogle();
                            },
                      // Borde y forma vienen del outlinedButtonTheme.
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: cs.surface,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (auth.isSigningIn ||
                              auth.isValidatingAuthorization)
                            const SizedBox.square(
                              key: Key('auth_loading'),
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          const SizedBox(width: 12),
                          Text(
                            auth.isValidatingAuthorization
                                ? 'Validando autorización...'
                                : 'Iniciar sesión con Google',
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (loginMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        loginMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Separador ENTERPRISE ACCESS
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ENTERPRISE ACCESS',
                            style: context.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.faintText,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Indicador de conexión segura
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Conexión segura cifrada',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Footer links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _footerLink('Soporte', () {}),
                  _footerDivider(),
                  _footerLink('Política de privacidad', () {}),
                  _footerDivider(),
                  _footerLink('Términos de servicio', () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerLink(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _footerDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '•',
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colors.faintText,
        ),
      ),
    );
  }
}
