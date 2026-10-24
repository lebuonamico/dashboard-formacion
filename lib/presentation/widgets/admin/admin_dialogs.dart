import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_styles.dart';

Future<({String email, RolUsuario rol})?> mostrarDialogoAltaUsuario(
  BuildContext context,
) {
  return showDialog<({String email, RolUsuario rol})>(
    context: context,
    builder: (_) => const _DialogoAltaUsuario(),
  );
}

Future<RolUsuario?> mostrarDialogoCambiarRol(
  BuildContext context, {
  required String email,
  required RolUsuario? rolActual,
}) {
  return showDialog<RolUsuario>(
    context: context,
    builder: (_) => _DialogoCambiarRol(email: email, rolActual: rolActual),
  );
}

Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String etiquetaConfirmar,
  required Color color,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (ctx) => _MarcoDialogo(
      titulo: titulo,
      ancho: 460,
      children: [
        Text(
          mensaje,
          style: TextStyle(
            fontSize: 14,
            color: context.colores.textoIntermedio,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_confirmar'),
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(etiquetaConfirmar),
            ),
          ],
        ),
      ],
    ),
  );
  return confirmado ?? false;
}

/// Elige los líderes de un área o un equipo entre los usuarios activos con
/// [rol]. Devuelve el conjunto completo de emails, o `null` si se cancela.
Future<Set<String>?> mostrarDialogoLideres(
  BuildContext context, {
  required String titulo,
  required String subtitulo,
  required RolUsuario rol,
  required List<UsuarioAutorizado> usuarios,
  required Set<String> seleccionados,
  required Map<String, String> nombrePorEmail,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => _DialogoLideres(
      titulo: titulo,
      subtitulo: subtitulo,
      rol: rol,
      usuarios: usuarios,
      seleccionados: seleccionados,
      nombrePorEmail: nombrePorEmail,
    ),
  );
}

class _DialogoLideres extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final RolUsuario rol;
  final List<UsuarioAutorizado> usuarios;
  final Set<String> seleccionados;
  final Map<String, String> nombrePorEmail;

  const _DialogoLideres({
    required this.titulo,
    required this.subtitulo,
    required this.rol,
    required this.usuarios,
    required this.seleccionados,
    required this.nombrePorEmail,
  });

  @override
  State<_DialogoLideres> createState() => _DialogoLideresState();
}

class _DialogoLideresState extends State<_DialogoLideres> {
  late final Set<String> _marcados = {...widget.seleccionados};

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final candidatos = {
      for (final usuario in widget.usuarios)
        if (usuario.estado == EstadoUsuario.activo &&
            usuario.rolConocido == widget.rol)
          usuario.email,
    };
    // Los asignados que perdieron el rol o el acceso se listan igual, para
    // poder quitarlos.
    final sinAcceso = widget.seleccionados.difference(candidatos);
    final emails = [...candidatos, ...sinAcceso]..sort();
    final sinCambios =
        _marcados.length == widget.seleccionados.length &&
        _marcados.containsAll(widget.seleccionados);

    return _MarcoDialogo(
      titulo: widget.titulo,
      subtitulo: widget.subtitulo,
      children: [
        if (emails.isEmpty)
          Text(
            'No hay usuarios activos con el rol ${widget.rol.label}. Dalos de '
            'alta o cambiales el rol desde la pestaña Usuarios.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final email in emails)
                    CheckboxListTile(
                      key: Key('admin_lider_$email'),
                      value: _marcados.contains(email),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: cs.primary,
                      onChanged: (valor) => setState(() {
                        if (valor == true) {
                          _marcados.add(email);
                        } else {
                          _marcados.remove(email);
                        }
                      }),
                      title: Text(
                        email,
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                      subtitle: _subtitulo(email, sinAcceso.contains(email)),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_lideres_confirmar'),
              onPressed: sinCambios
                  ? null
                  : () => Navigator.of(context).pop({..._marcados}),
              child: const Text('Guardar líderes'),
            ),
          ],
        ),
      ],
    );
  }

  Widget? _subtitulo(String email, bool sinAcceso) {
    final nombre = widget.nombrePorEmail[email];
    final partes = [
      ?nombre,
      if (sinAcceso) 'Ya no tiene el rol ${widget.rol.label} o está sin acceso',
    ];
    if (partes.isEmpty) return null;
    return Text(
      partes.join(' · '),
      style: TextStyle(
        fontSize: 12,
        color: sinAcceso
            ? context.colores.advertencia.texto
            : context.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DialogoAltaUsuario extends StatefulWidget {
  const _DialogoAltaUsuario();

  @override
  State<_DialogoAltaUsuario> createState() => _DialogoAltaUsuarioState();
}

class _DialogoAltaUsuarioState extends State<_DialogoAltaUsuario> {
  final _claveFormulario = GlobalKey<FormState>();
  final _controladorEmail = TextEditingController();
  RolUsuario _rol = RolUsuario.lider;

  @override
  void dispose() {
    _controladorEmail.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_claveFormulario.currentState?.validate() != true) return;
    Navigator.of(
      context,
    ).pop((email: _controladorEmail.text.trim().toLowerCase(), rol: _rol));
  }

  @override
  Widget build(BuildContext context) {
    return _MarcoDialogo(
      titulo: 'Nuevo usuario',
      subtitulo:
          'El usuario queda habilitado para iniciar sesión con su cuenta de Google.',
      children: [
        Form(
          key: _claveFormulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('admin_alta_email'),
                controller: _controladorEmail,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: adminInputDecoration(
                  'nombre.apellido@finnegans.com',
                  Icons.alternate_email,
                  label: 'Email corporativo',
                ),
                onFieldSubmitted: (_) => _confirmar(),
                validator: _validarEmail,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RolUsuario>(
                key: const Key('admin_alta_rol'),
                initialValue: _rol,
                isExpanded: true,
                decoration: adminInputDecoration(
                  'Rol',
                  Icons.badge_outlined,
                  label: 'Rol',
                ),
                items: RolUsuario.values
                    .map(
                      (rol) => DropdownMenuItem(
                        value: rol,
                        child: Text(
                          '${rol.label} — ${rol.descripcion}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (valor) =>
                    setState(() => _rol = valor ?? RolUsuario.lider),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_alta_confirmar'),
              onPressed: _confirmar,
              child: const Text('Crear usuario'),
            ),
          ],
        ),
      ],
    );
  }

  static String? _validarEmail(String? valor) {
    final email = valor?.trim() ?? '';
    if (email.isEmpty) return 'Ingresá un email.';
    if (!RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(email)) {
      return 'El email no tiene un formato válido.';
    }
    return null;
  }
}

class _DialogoCambiarRol extends StatefulWidget {
  final String email;
  final RolUsuario? rolActual;

  const _DialogoCambiarRol({required this.email, required this.rolActual});

  @override
  State<_DialogoCambiarRol> createState() => _DialogoCambiarRolState();
}

class _DialogoCambiarRolState extends State<_DialogoCambiarRol> {
  late RolUsuario _rol = widget.rolActual ?? RolUsuario.lider;

  @override
  Widget build(BuildContext context) {
    final sinCambio = _rol == widget.rolActual;
    final cs = context.colorScheme;

    return _MarcoDialogo(
      titulo: 'Cambiar rol',
      subtitulo: widget.email,
      children: [
        if (widget.rolActual == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Este usuario tiene un rol que ya no se usa. Elegí uno de la '
              'lista para reemplazarlo.',
              style: TextStyle(
                fontSize: 13,
                color: context.colores.advertencia.texto,
              ),
            ),
          ),
        RadioGroup<RolUsuario>(
          groupValue: _rol,
          onChanged: (valor) => setState(() => _rol = valor ?? _rol),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: RolUsuario.values
                .map(
                  (rol) => RadioListTile<RolUsuario>(
                    key: Key('admin_rol_${rol.name}'),
                    value: rol,
                    contentPadding: EdgeInsets.zero,
                    activeColor: cs.primary,
                    title: Text(
                      rol.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      rol.descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('admin_rol_confirmar'),
              onPressed: sinCambio
                  ? null
                  : () => Navigator.of(context).pop(_rol),
              child: const Text('Guardar rol'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MarcoDialogo extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final double ancho;
  final List<Widget> children;

  const _MarcoDialogo({
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.ancho = 520,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: ancho),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        if (subtitulo != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitulo!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
