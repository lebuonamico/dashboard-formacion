import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LoginCard(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FooterLink('Soporte', () {}),
                  const _FooterDivider(),
                  _FooterLink('Política de privacidad', () {}),
                  const _FooterDivider(),
                  _FooterLink('Términos de servicio', () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends ConsumerWidget {
  const _LoginCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginMessage = ref.watch(authProvider.select((auth) => auth.error));
    final cs = context.colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
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
          const _BrandHeader(),
          const SizedBox(height: 32),
          const _GoogleSignInButton(),
          if (loginMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              loginMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
          ],
          const SizedBox(height: 28),
          const _EnterpriseDivider(),
          const SizedBox(height: 24),
          const _SecureConnection(),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo_finnegans.png',
            width: 52,
            height: 52,
          ),
        ),
        const SizedBox(height: 16),
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
      ],
    );
  }
}

class _GoogleSignInButton extends ConsumerWidget {
  const _GoogleSignInButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final busy = auth.isSigningIn || auth.isValidatingAuthorization;
    final cs = context.colorScheme;
    return OutlinedButton(
      onPressed: busy
          ? null
          : () async {
              if (!auth.enabled) {
                context.go('/dashboard');
                return;
              }
              await ref.read(authProvider.notifier).signInWithGoogle();
            },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: cs.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
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
    );
  }
}

class _EnterpriseDivider extends StatelessWidget {
  const _EnterpriseDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'ENTERPRISE ACCESS',
          style: context.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.faintText,
            letterSpacing: 1.2,
          ),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

class _SecureConnection extends StatelessWidget {
  const _SecureConnection();

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Conexión segura cifrada',
          style: context.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _FooterLink(this.text, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
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

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Text(
      '•',
      style: context.textTheme.labelSmall?.copyWith(
        color: context.colors.faintText,
      ),
    ),
  );
}
