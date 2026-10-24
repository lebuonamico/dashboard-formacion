import 'package:app_finnegans/presentation/widgets/shared/margenes_pantalla.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/fade_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/domain/repositorios/usuarios_autorizados_repository.dart';
import 'package:app_finnegans/presentation/providers/admin_providers.dart';
import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';
import 'package:app_finnegans/presentation/providers/estructura_providers.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_actions_bar.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_dialogs.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_estructura.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_users_table.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_top_bar.dart';
import 'package:app_finnegans/presentation/widgets/admin/admin_filters.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String? _accionEnCurso;

  @override
  Widget build(BuildContext context) {
    final acceso = ref.watch(accesoAdminProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Panel de administrador'),
          Expanded(
            child: switch (acceso) {
              AccesoAdmin.permitido => _pestanas(),
              AccesoAdmin.denegado => const _EstadoCentrado(
                icono: Icons.lock_outline,
                titulo: 'No tenés permiso para ver esta sección',
                mensaje:
                    'El panel de administración está reservado para los '
                    'usuarios con rol Administrador o Academia.',
              ),
              AccesoAdmin.sinSupabase => const _EstadoCentrado(
                icono: Icons.cloud_off_outlined,
                titulo: 'El panel no está disponible',
                mensaje:
                    'Esta versión de la aplicación no está conectada a '
                    'la lista de usuarios, así que no hay usuarios para '
                    'administrar.',
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _pestanas() {
    final cs = context.colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: paddingPantalla.left),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: const TabBar(
              key: Key('admin_pestanas'),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Usuarios'),
                Tab(text: 'Áreas y equipos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [_contenido(), const AdminEstructura()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    final usuariosFiltrados = ref.watch(usuariosAdminFiltradosProvider);
    final seleccionado = ref.watch(usuarioSeleccionadoAdminProvider);
    final auth = ref.watch(authControllerProvider);
    final cs = context.colorScheme;

    return ListView(
      padding: paddingPantalla,
      children: [
        Text(
          'Usuarios del sistema',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quién puede iniciar sesión en la aplicación y con qué rol. '
          'Bloquear y eliminar se pueden deshacer más adelante.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        AdminFilters(
          hayFiltrosActivos: ref.watch(filtrosAdminActivosProvider),
          onLimpiar: _limpiarFiltros,
        ),
        const SizedBox(height: 16),
        AdminActionsBar(
          seleccionado: seleccionado,
          fueraDelFiltro: ref.watch(seleccionFueraDelFiltroAdminProvider),
          accionEnCurso: _accionEnCurso,
          emailPropio: auth.email,
          onCrear: _crearUsuario,
          onCambiarRol: _cambiarRol,
          onBloquear: _bloquear,
          onDesbloquear: _desbloquear,
          onEliminar: _eliminar,
          onRestaurar: _restaurar,
        ),
        const SizedBox(height: 20),
        usuariosFiltrados.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _EstadoCentrado(
            icono: Icons.error_outline,
            titulo: 'No pudimos cargar los usuarios',
            mensaje: _mensajeDeError(error),
            color: cs.error,
          ),
          data: (usuarios) => FadeIn(
            child: usuarios.isEmpty
                ? const _EstadoCentrado(
                    icono: Icons.manage_accounts_outlined,
                    titulo: 'No hay usuarios para mostrar',
                    mensaje:
                        'Probá limpiar los filtros o dar de alta un usuario nuevo.',
                  )
                : AdminUsuariosTable(
                    usuarios: usuarios,
                    estructura: ref.watch(estructuraProvider).value,
                    nomina: ref.watch(empleadosProvider).value,
                    emailSeleccionado: ref.watch(
                      emailSeleccionadoAdminProvider,
                    ),
                    emailPropio: auth.email,
                    onSeleccionar: (email) =>
                        ref
                                .read(emailSeleccionadoAdminProvider.notifier)
                                .state =
                            email,
                  ),
          ),
        ),
      ],
    );
  }

  void _limpiarFiltros() {
    ref.read(dataFilterSelectionProvider('admin').notifier).clear();
    ref.read(busquedaUsuarioAdminProvider.notifier).state = '';
    ref.read(filtroRolAdminProvider.notifier).state = null;
    ref.read(filtroEstadoAdminProvider.notifier).state = null;
  }

  UsuariosAutorizadosRepository _repositorio() {
    final repositorio = ref.read(usuariosAutorizadosRepositoryProvider);
    if (repositorio == null) {
      throw const FormatException(
        'El panel de administración no está disponible en esta versión.',
      );
    }
    return repositorio;
  }

  Future<void> _crearUsuario() async {
    final datos = await mostrarDialogoAltaUsuario(context);
    if (datos == null) return;
    await _ejecutar(
      clave: 'admin_crear',
      emailAfectado: datos.email,
      exito: 'Se dio de alta a ${datos.email}.',
      accion: (repositorio) => repositorio.crear(
        UsuarioAutorizado.nuevo(
          email: datos.email,
          rol: datos.rol,
          ahora: DateTime.now().toUtc(),
        ),
      ),
      alTerminar: () {
        ref.read(filtroEstadoAdminProvider.notifier).state = null;
        ref.read(emailSeleccionadoAdminProvider.notifier).state = datos.email;
      },
    );
  }

  Future<void> _cambiarRol() async {
    final usuario = ref.read(usuarioSeleccionadoAdminProvider);
    if (usuario == null) return;
    final rol = await mostrarDialogoCambiarRol(
      context,
      email: usuario.email,
      rolActual: usuario.rolConocido,
    );
    if (rol == null) return;
    await _guardar(
      clave: 'admin_cambiar_rol',
      usuario: usuario.conRol(rol),
      exito: '${usuario.email} ahora tiene el rol ${rol.label}.',
    );
  }

  Future<void> _bloquear() async {
    final usuario = ref.read(usuarioSeleccionadoAdminProvider);
    if (usuario == null) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Bloquear usuario',
      mensaje:
          '${usuario.email} no va a poder entrar a la aplicación hasta que lo '
          'desbloquees.',
      etiquetaConfirmar: 'Bloquear',
      color: context.colores.advertencia.texto,
    );
    if (!confirmado) return;
    await _guardar(
      clave: 'admin_bloquear',
      usuario: usuario.bloqueado(DateTime.now().toUtc()),
      exito: 'Se bloqueó a ${usuario.email}.',
    );
  }

  Future<void> _desbloquear() async {
    final usuario = ref.read(usuarioSeleccionadoAdminProvider);
    if (usuario == null) return;
    await _guardar(
      clave: 'admin_desbloquear',
      usuario: usuario.desbloqueado(),
      exito: 'Se desbloqueó a ${usuario.email}.',
    );
  }

  Future<void> _eliminar() async {
    final usuario = ref.read(usuarioSeleccionadoAdminProvider);
    if (usuario == null) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Eliminar usuario',
      mensaje:
          '${usuario.email} ya no va a poder entrar a la aplicación. Si más '
          'adelante lo necesitás, lo podés restaurar desde la lista.',
      etiquetaConfirmar: 'Eliminar',
      color: context.colorScheme.error,
    );
    if (!confirmado) return;
    await _guardar(
      clave: 'admin_eliminar',
      usuario: usuario.eliminado(DateTime.now().toUtc()),
      exito: 'Se eliminó a ${usuario.email}.',
    );
  }

  Future<void> _restaurar() async {
    final usuario = ref.read(usuarioSeleccionadoAdminProvider);
    if (usuario == null) return;
    await _guardar(
      clave: 'admin_restaurar',
      usuario: usuario.restaurado(),
      exito: 'Se restauró a ${usuario.email}.',
    );
  }

  Future<void> _guardar({
    required String clave,
    required UsuarioAutorizado usuario,
    required String exito,
  }) {
    return _ejecutar(
      clave: clave,
      emailAfectado: usuario.email,
      exito: exito,
      accion: (repositorio) => repositorio.guardar(usuario),
    );
  }

  Future<void> _ejecutar({
    required String clave,
    required String emailAfectado,
    required String exito,
    required Future<void> Function(UsuariosAutorizadosRepository) accion,
    VoidCallback? alTerminar,
  }) async {
    if (_accionEnCurso != null) return;
    setState(() => _accionEnCurso = clave);
    try {
      await accion(_repositorio());
      ref.invalidate(usuariosAutorizadosProvider);
      // Cambiar un rol borra en la base las asignaciones que dejan de
      // aplicar: la columna Lidera y los líderes tienen que recargarse.
      ref.invalidate(estructuraProvider);
      await ref.read(usuariosAutorizadosProvider.future);
      final auth = ref.read(authControllerProvider);
      if (emailAfectado == auth.email) {
        await auth.validateAuthorization();
      }
      alTerminar?.call();
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
      debugPrint('Panel de administración: $error');
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

  static String _mensajeDeError(Object error) => error is FormatException
      ? error.message
      : 'Revisá tu conexión e intentá nuevamente.';
}

class _EstadoCentrado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final Color? color;

  const _EstadoCentrado({
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
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
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
