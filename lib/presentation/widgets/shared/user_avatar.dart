import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';

/// Avatar del usuario logueado, con su inicial.
///
/// Cuando la app corre sin Supabase (modo local) no hay sesión, así que cae en
/// la 'U' genérica que había antes.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).email;
    final inicial = _inicialDe(email);

    return Tooltip(
      message: email ?? 'Sin sesión iniciada',
      child: CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFF0D53C3),
        child: Text(inicial, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  /// Primera letra del mail. Si no hay sesión o el mail viene raro, 'U'.
  static String _inicialDe(String? email) {
    final limpio = email?.trim() ?? '';
    if (limpio.isEmpty) return 'U';
    final inicial = limpio.characters.first.toUpperCase();
    return RegExp(r'[A-ZÁÉÍÓÚÑ0-9]').hasMatch(inicial) ? inicial : 'U';
  }
}
