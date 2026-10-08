import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';

/// Usuario logueado en el top bar: foto, nombre y mail. Al hacer clic abre una
/// tarjeta con el detalle de la cuenta, incluido el rol.
///
/// Cuando la app corre sin Supabase (modo local) no hay sesión, así que cae en
/// la 'U' genérica y en el texto "Modo local".
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final datos = _DatosUsuario(
      email: auth.email,
      nombre: auth.nombre,
      fotoUrl: auth.fotoUrl,
      rol: auth.rol,
      modoLocal: !auth.enabled,
    );

    return PopupMenuButton<void>(
      tooltip: 'Mi cuenta',
      offset: const Offset(0, 52),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _TarjetaUsuario(datos: datos),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FotoUsuario(datos: datos, radio: 18),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    datos.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (datos.subtitulo != null)
                    Text(
                      datos.subtitulo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatosUsuario {
  final String? email;
  final String? nombre;
  final String? fotoUrl;
  final String? rol;
  final bool modoLocal;

  const _DatosUsuario({
    required this.email,
    required this.nombre,
    required this.fotoUrl,
    required this.rol,
    required this.modoLocal,
  });

  /// Primera línea del chip: el nombre si Google lo informa, si no el mail.
  String get titulo =>
      nombre ?? email ?? (modoLocal ? 'Modo local' : 'Sin sesión iniciada');

  /// Segunda línea: el mail, solo cuando no se usó ya como título.
  String? get subtitulo {
    if (nombre != null) return email;
    if (email == null && modoLocal) return 'Sin sesión iniciada';
    return null;
  }

  /// Primera letra del nombre o del mail. Si no hay sesión o viene raro, 'U'.
  String get inicial {
    final limpio = (nombre ?? email)?.trim() ?? '';
    if (limpio.isEmpty) return 'U';
    final inicial = limpio.characters.first.toUpperCase();
    return RegExp(r'[A-ZÁÉÍÓÚÑ0-9]').hasMatch(inicial) ? inicial : 'U';
  }
}

/// Foto de Google recortada en círculo; sin foto, o si no carga, la inicial.
class _FotoUsuario extends StatelessWidget {
  final _DatosUsuario datos;
  final double radio;

  const _FotoUsuario({required this.datos, required this.radio});

  @override
  Widget build(BuildContext context) {
    final inicial = CircleAvatar(
      radius: radio,
      backgroundColor: const Color(0xFF0D53C3),
      child: Text(
        datos.inicial,
        style: TextStyle(color: Colors.white, fontSize: radio * 0.85),
      ),
    );
    final url = datos.fotoUrl;
    if (url == null) return inicial;

    return ClipOval(
      child: Image.network(
        url,
        width: radio * 2,
        height: radio * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => inicial,
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  final _DatosUsuario datos;

  const _TarjetaUsuario({required this.datos});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FotoUsuario(datos: datos, radio: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        datos.nombre ??
                            (datos.modoLocal ? 'Modo local' : 'Usuario'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        datos.email ?? 'Sin sesión iniciada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            const Text(
              'Rol',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            _BadgeRol(rol: datos.rol, modoLocal: datos.modoLocal),
          ],
        ),
      ),
    );
  }
}

class _BadgeRol extends StatelessWidget {
  final String? rol;
  final bool modoLocal;

  const _BadgeRol({required this.rol, required this.modoLocal});

  @override
  Widget build(BuildContext context) {
    final conocido = RolUsuario.fromString(rol);
    final crudo = rol?.trim() ?? '';

    // Un rol irreconocible se muestra tal cual, en ámbar, como en el panel admin.
    final (texto, color, fondo, descripcion) = conocido != null
        ? (
            conocido.label,
            const Color(0xFF0D53C3),
            const Color(0xFFE8F0FC),
            conocido.descripcion,
          )
        : (
            modoLocal ? 'Sin rol' : (crudo.isEmpty ? 'Sin rol' : crudo),
            const Color(0xFFD97706),
            const Color(0xFFFEF3C7),
            modoLocal
                ? 'La app corre sin Supabase, no hay usuario autenticado.'
                : 'Rol no reconocido por el sistema.',
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          descripcion,
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}
