import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';

class AdminActionsBar extends StatelessWidget {
  final UsuarioAutorizado? seleccionado;
  final bool fueraDelFiltro;
  final String? accionEnCurso;
  final String? emailPropio;
  final VoidCallback onCrear;
  final VoidCallback onCambiarRol;
  final VoidCallback onBloquear;
  final VoidCallback onDesbloquear;
  final VoidCallback onEliminar;
  final VoidCallback onRestaurar;

  const AdminActionsBar({
    super.key,
    required this.seleccionado,
    required this.fueraDelFiltro,
    required this.accionEnCurso,
    required this.emailPropio,
    required this.onCrear,
    required this.onCambiarRol,
    required this.onBloquear,
    required this.onDesbloquear,
    required this.onEliminar,
    required this.onRestaurar,
  });

  @override
  Widget build(BuildContext context) {
    final usuario = seleccionado;
    final hayAccion = accionEnCurso != null;
    final esPropio = usuario?.esMismoUsuario(emailPropio) ?? false;
    final habilitado = usuario != null && !esPropio && !hayAccion;
    final eliminado = usuario?.estado == EstadoUsuario.eliminado;
    final bloqueado = usuario?.estado == EstadoUsuario.bloqueado;
    final colores = context.colores;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezado(context, usuario, esPropio),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _boton(
                context,
                clave: 'admin_crear',
                etiqueta: 'Nuevo usuario',
                icono: Icons.person_add_alt_1_outlined,
                onPressed: hayAccion ? null : onCrear,
                destacado: true,
              ),
              _boton(
                context,
                clave: 'admin_cambiar_rol',
                etiqueta: 'Cambiar rol',
                icono: Icons.badge_outlined,
                onPressed: habilitado ? onCambiarRol : null,
                tooltip: _motivoDeshabilitado(usuario, esPropio),
              ),
              if (bloqueado)
                _boton(
                  context,
                  clave: 'admin_desbloquear',
                  etiqueta: 'Desbloquear',
                  icono: Icons.lock_open_outlined,
                  onPressed: habilitado ? onDesbloquear : null,
                  tooltip: _motivoDeshabilitado(usuario, esPropio),
                )
              else
                _boton(
                  context,
                  clave: 'admin_bloquear',
                  etiqueta: 'Bloquear',
                  icono: Icons.block_outlined,
                  onPressed: habilitado && !eliminado ? onBloquear : null,
                  tooltip: eliminado
                      ? 'El usuario está eliminado: restauralo antes de bloquearlo.'
                      : _motivoDeshabilitado(usuario, esPropio),
                  color: colores.advertencia.texto,
                ),
              if (eliminado)
                _boton(
                  context,
                  clave: 'admin_restaurar',
                  etiqueta: 'Restaurar',
                  icono: Icons.restore_outlined,
                  onPressed: habilitado ? onRestaurar : null,
                  tooltip: _motivoDeshabilitado(usuario, esPropio),
                )
              else
                _boton(
                  context,
                  clave: 'admin_eliminar',
                  etiqueta: 'Eliminar',
                  icono: Icons.person_remove_outlined,
                  onPressed: habilitado ? onEliminar : null,
                  tooltip: _motivoDeshabilitado(usuario, esPropio),
                  color: context.colorScheme.error,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _encabezado(
    BuildContext context,
    UsuarioAutorizado? usuario,
    bool esPropio,
  ) {
    final cs = context.colorScheme;
    if (usuario == null) {
      return Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seleccioná un usuario de la lista para habilitar las acciones.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.person_outline, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Seleccionado: ${usuario.email}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              if (fueraDelFiltro)
                Text(
                  '(no aparece con los filtros actuales)',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colores.advertencia.texto,
                  ),
                ),
              if (esPropio)
                Text(
                  'Es tu propio usuario: no podés modificarlo desde acá.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _motivoDeshabilitado(UsuarioAutorizado? usuario, bool esPropio) {
    if (usuario == null) return 'Seleccioná un usuario de la lista.';
    if (esPropio) {
      return 'No podés modificar tu propio usuario: perderías el acceso al panel.';
    }
    return null;
  }

  Widget _boton(
    BuildContext context, {
    required String clave,
    required String etiqueta,
    required IconData icono,
    required VoidCallback? onPressed,
    String? tooltip,
    Color? color,
    bool destacado = false,
  }) {
    final cs = context.colorScheme;
    final enCurso = accionEnCurso == clave;
    final boton = OutlinedButton.icon(
      key: Key(clave),
      onPressed: enCurso ? null : onPressed,
      icon: enCurso
          ? SizedBox.square(
              key: Key('loading_$clave'),
              dimension: 18,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icono, size: 18),
      label: Text(etiqueta),
      // Forma y borde vienen del outlinedButtonTheme.
      style:
          OutlinedButton.styleFrom(
            foregroundColor: color,
            backgroundColor: destacado ? cs.primary : null,
            disabledForegroundColor: cs.onSurfaceVariant.withValues(
              alpha: 0.45,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ).copyWith(
            foregroundColor: destacado
                ? WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? cs.onPrimary.withValues(alpha: 0.6)
                        : cs.onPrimary,
                  )
                : null,
          ),
    );
    return tooltip == null ? boton : Tooltip(message: tooltip, child: boton);
  }
}
