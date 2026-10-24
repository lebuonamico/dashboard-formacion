import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/domain/repositorios/estructura_repository.dart';
import 'package:app_finnegans/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_dialogs.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_styles.dart';
import 'package:app_finnegans/presentation/widgets/shared/etiqueta_color.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestaña "Áreas y equipos" del panel. Las áreas y los equipos vienen de la
/// importación de nómina y acá solo se consultan; lo único que se cambia son
/// sus líderes.
class AdminEstructura extends ConsumerStatefulWidget {
  const AdminEstructura({super.key});

  @override
  ConsumerState<AdminEstructura> createState() => _AdminEstructuraState();
}

class _AdminEstructuraState extends ConsumerState<AdminEstructura> {
  String? _accionEnCurso;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    if (ref.watch(estructuraRepositoryProvider) == null) {
      return const _Aviso(
        icono: Icons.cloud_off_outlined,
        titulo: 'Las áreas y los equipos no están disponibles',
        mensaje:
            'Esta versión de la aplicación no está conectada a la base, así '
            'que no hay líderes para asignar.',
      );
    }
    final estructura = ref.watch(estructuraProvider);

    return ListView(
      padding: paddingPantalla,
      children: [
        Text(
          'Áreas y equipos',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Las áreas y los equipos se crean al importar la nómina, con el '
          'Sector y el Equipo de cada colaborador. Desde acá se asignan sus '
          'líderes.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 420,
          child: TextField(
            key: const Key('estructura_busqueda'),
            decoration: adminInputDecoration(
              'Buscar área o equipo',
              Icons.search,
            ),
            onChanged: (valor) =>
                ref.read(busquedaEstructuraAdminProvider.notifier).state =
                    valor,
          ),
        ),
        const SizedBox(height: 20),
        estructura.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _Aviso(
            icono: Icons.error_outline,
            titulo: 'No pudimos cargar las áreas y los equipos',
            mensaje: error is FormatException
                ? error.message
                : 'Revisá tu conexión e intentá nuevamente.',
            color: cs.error,
          ),
          data: (datos) => FadeIn(child: _listado(datos!)),
        ),
      ],
    );
  }

  Widget _listado(EstructuraOrganizacional estructura) {
    final consulta = ref
        .watch(busquedaEstructuraAdminProvider)
        .trim()
        .toLowerCase();
    final conteos = _Conteos(ref.watch(empleadosProvider).value ?? const []);
    final nombres = _nombrePorEmail();
    final areas = estructura.areasOrdenadas.where((area) {
      if (consulta.isEmpty) return true;
      return area.nombre.toLowerCase().contains(consulta) ||
          estructura
              .equiposDe(area.id)
              .any((equipo) => equipo.nombre.toLowerCase().contains(consulta));
    }).toList();

    if (areas.isEmpty) {
      return _Aviso(
        icono: Icons.account_tree_outlined,
        titulo: consulta.isEmpty
            ? 'Todavía no hay áreas'
            : 'Ningún área o equipo coincide con la búsqueda',
        mensaje: consulta.isEmpty
            ? 'Se crean al importar la nómina desde Configuración.'
            : 'Probá con otro nombre.',
      );
    }

    return Column(
      children: [
        for (final area in areas) ...[
          _TarjetaArea(
            area: area,
            equipos: estructura.equiposDe(area.id),
            conteos: conteos,
            nombrePorEmail: nombres,
            habilitado: _accionEnCurso == null,
            onLideres: () => _lideresArea(area),
            onLideresEquipo: (equipo) => _lideresEquipo(equipo),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Map<String, String> _nombrePorEmail() => {
    for (final empleado in ref.watch(empleadosProvider).value ?? const [])
      if (empleado.mail.trim().isNotEmpty)
        EstructuraOrganizacional.normalizarEmail(empleado.mail):
            empleado.nombreCompleto,
  };

  Future<void> _lideresArea(Area area) async {
    final elegidos = await _elegirLideres(
      titulo: 'Líderes de ${area.nombre}',
      subtitulo:
          'Ven todos los equipos del área. Solo se pueden elegir usuarios '
          'activos con el rol Área.',
      rol: RolUsuario.area,
      actuales: area.lideres,
    );
    if (elegidos == null) return;
    await _ejecutar(
      clave: 'lideres_area',
      exito: 'Se actualizaron los líderes de ${area.nombre}.',
      accion: (repositorio) =>
          repositorio.asignarLideresArea(area.id, elegidos),
    );
  }

  Future<void> _lideresEquipo(Equipo equipo) async {
    final elegidos = await _elegirLideres(
      titulo: 'Líderes de ${equipo.nombre}',
      subtitulo:
          'Ven a los integrantes del equipo. Solo se pueden elegir usuarios '
          'activos con el rol Líder de equipo.',
      rol: RolUsuario.lider,
      actuales: equipo.lideres,
    );
    if (elegidos == null) return;
    await _ejecutar(
      clave: 'lideres_equipo',
      exito: 'Se actualizaron los líderes de ${equipo.nombre}.',
      accion: (repositorio) =>
          repositorio.asignarLideresEquipo(equipo.id, elegidos),
    );
  }

  Future<Set<String>?> _elegirLideres({
    required String titulo,
    required String subtitulo,
    required RolUsuario rol,
    required Set<String> actuales,
  }) async {
    final List<UsuarioAutorizado> usuarios;
    try {
      usuarios = await ref.read(usuariosAutorizadosProvider.future);
    } on Object catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FormatException
                ? error.message
                : 'No se pudo cargar la lista de usuarios.',
          ),
        ),
      );
      return null;
    }
    if (!mounted) return null;
    return mostrarDialogoLideres(
      context,
      titulo: titulo,
      subtitulo: subtitulo,
      rol: rol,
      usuarios: usuarios,
      seleccionados: actuales,
      nombrePorEmail: _nombrePorEmail(),
    );
  }

  Future<void> _ejecutar({
    required String clave,
    required String exito,
    required Future<void> Function(EstructuraRepository) accion,
  }) async {
    if (_accionEnCurso != null) return;
    final repositorio = ref.read(estructuraRepositoryProvider);
    if (repositorio == null) return;
    setState(() => _accionEnCurso = clave);
    try {
      await accion(repositorio);
      // Los líderes definen qué ve cada uno y se muestran en Equipos y
      // Áreas: recargar la estructura actualiza todo.
      ref.invalidate(estructuraProvider);
      await ref.read(estructuraProvider.future);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(exito)));
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      debugPrint('Panel de áreas y equipos: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar la acción. Intentá nuevamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }
}

/// Colaboradores activos por área y por equipo, por clave de nómina.
class _Conteos {
  final Map<String, int> _porArea = {};
  final Map<(String, String), int> _porEquipo = {};

  _Conteos(Iterable<Empleado> empleados) {
    for (final empleado in empleados) {
      if (!empleado.activo) continue;
      final area = EstructuraOrganizacional.claveNomina(empleado.area);
      _porArea[area] = (_porArea[area] ?? 0) + 1;
      final equipo = (
        area,
        EstructuraOrganizacional.claveNomina(empleado.equipo),
      );
      _porEquipo[equipo] = (_porEquipo[equipo] ?? 0) + 1;
    }
  }

  int deArea(Area area) => _porArea[area.claveNomina] ?? 0;

  int deEquipo(Area area, Equipo equipo) =>
      _porEquipo[(area.claveNomina, equipo.claveNomina)] ?? 0;
}

String _colaboradores(int cantidad) =>
    '$cantidad ${cantidad == 1 ? 'colaborador' : 'colaboradores'}';

class _TarjetaArea extends StatelessWidget {
  final Area area;
  final List<Equipo> equipos;
  final _Conteos conteos;
  final Map<String, String> nombrePorEmail;
  final bool habilitado;
  final VoidCallback onLideres;
  final ValueChanged<Equipo> onLideresEquipo;

  const _TarjetaArea({
    required this.area,
    required this.equipos,
    required this.conteos,
    required this.nombrePorEmail,
    required this.habilitado,
    required this.onLideres,
    required this.onLideresEquipo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final detalle =
        '${equipos.length} ${equipos.length == 1 ? 'equipo' : 'equipos'} · '
        '${_colaboradores(conteos.deArea(area))}';

    return Container(
      key: Key('estructura_area_${area.id}'),
      width: double.infinity,
      decoration: context.panel(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.account_tree_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.nombre,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Lideres(
            clave: 'estructura_lideres_area_${area.id}',
            etiqueta: 'Líderes de área',
            emails: area.lideres,
            nombrePorEmail: nombrePorEmail,
            habilitado: habilitado,
            onEditar: onLideres,
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant),
          if (equipos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'La nómina no trae equipos para esta área.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          for (final equipo in equipos)
            _FilaEquipo(
              equipo: equipo,
              colaboradores: conteos.deEquipo(area, equipo),
              nombrePorEmail: nombrePorEmail,
              habilitado: habilitado,
              onLideres: () => onLideresEquipo(equipo),
            ),
        ],
      ),
    );
  }
}

class _FilaEquipo extends StatelessWidget {
  final Equipo equipo;
  final int colaboradores;
  final Map<String, String> nombrePorEmail;
  final bool habilitado;
  final VoidCallback onLideres;

  const _FilaEquipo({
    required this.equipo,
    required this.colaboradores,
    required this.nombrePorEmail,
    required this.habilitado,
    required this.onLideres,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;

    return Padding(
      key: Key('estructura_equipo_${equipo.id}'),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2),
            child: Icon(
              Icons.groups_outlined,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipo.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  colaboradores == 0
                      ? 'Sin colaboradores activos en la nómina'
                      : _colaboradores(colaboradores),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Lideres(
              clave: 'estructura_lideres_equipo_${equipo.id}',
              etiqueta: 'Líderes',
              emails: equipo.lideres,
              nombrePorEmail: nombrePorEmail,
              habilitado: habilitado,
              onEditar: onLideres,
            ),
          ),
        ],
      ),
    );
  }
}

class _Lideres extends StatelessWidget {
  final String clave;
  final String etiqueta;
  final Set<String> emails;
  final Map<String, String> nombrePorEmail;
  final bool habilitado;
  final VoidCallback onEditar;

  const _Lideres({
    required this.clave,
    required this.etiqueta,
    required this.emails,
    required this.nombrePorEmail,
    required this.habilitado,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colores = context.colores;
    final ordenados = emails.toList()..sort();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$etiqueta:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        if (ordenados.isEmpty)
          Text(
            'Sin líderes asignados',
            style: TextStyle(fontSize: 12, color: colores.textoTenue),
          ),
        for (final email in ordenados)
          Tooltip(
            message: email,
            child: EtiquetaColor(
              texto: nombrePorEmail[email] ?? email,
              colores: ParColores(cs.onPrimaryContainer, cs.primaryContainer),
              icono: Icons.person_outline,
            ),
          ),
        TextButton(
          key: Key(clave),
          onPressed: habilitado ? onEditar : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 30),
          ),
          child: Text(ordenados.isEmpty ? 'Asignar' : 'Editar'),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final Color? color;

  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: context.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 34, color: color ?? cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color ?? cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
