import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';

enum AccesoAdmin { permitido, denegado, sinSupabase }

final accesoAdminProvider = Provider<AccesoAdmin>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (ref.watch(usuariosAutorizadosRepositoryProvider) == null) {
    return AccesoAdmin.sinSupabase;
  }
  return auth.esAdmin ? AccesoAdmin.permitido : AccesoAdmin.denegado;
});

final usuariosAutorizadosProvider =
    FutureProvider.autoDispose<List<UsuarioAutorizado>>((ref) async {
      final repositorio = ref.watch(usuariosAutorizadosRepositoryProvider);
      if (repositorio == null) {
        throw const FormatException(
          'El panel de administración no está disponible en esta versión.',
        );
      }
      return repositorio.getUsuarios();
    });

final busquedaUsuarioAdminProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);
final filtroRolAdminProvider = StateProvider.autoDispose<RolUsuario?>(
  (ref) => null,
);

final filtroEstadoAdminProvider = StateProvider.autoDispose<EstadoUsuario?>(
  (ref) => null,
);
final emailSeleccionadoAdminProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final filtrosAdminActivosProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(busquedaUsuarioAdminProvider).trim().isNotEmpty ||
      ref.watch(filtroRolAdminProvider) != null ||
      ref.watch(filtroEstadoAdminProvider) != null,
);

final usuariosAdminFiltradosProvider =
    Provider.autoDispose<AsyncValue<List<UsuarioAutorizado>>>((ref) {
      final usuarios = ref.watch(usuariosAutorizadosProvider);
      final busqueda = ref.watch(busquedaUsuarioAdminProvider).trim();
      final rol = ref.watch(filtroRolAdminProvider);
      final estado = ref.watch(filtroEstadoAdminProvider);

      return usuarios.whenData((lista) {
        final consulta = busqueda.toLowerCase();
        return lista.where((usuario) {
          final coincideTexto =
              consulta.isEmpty || usuario.email.contains(consulta);
          final coincideRol = rol == null || usuario.rolConocido == rol;
          final coincideEstado = estado == null || usuario.estado == estado;
          return coincideTexto && coincideRol && coincideEstado;
        }).toList();
      });
    });

final usuarioSeleccionadoAdminProvider =
    Provider.autoDispose<UsuarioAutorizado?>((ref) {
      final email = ref.watch(emailSeleccionadoAdminProvider);
      if (email == null) return null;
      final lista = ref.watch(usuariosAutorizadosProvider).value;
      if (lista == null) return null;
      for (final usuario in lista) {
        if (usuario.email == email) return usuario;
      }
      return null;
    });

final seleccionFueraDelFiltroAdminProvider = Provider.autoDispose<bool>((ref) {
  final seleccionado = ref.watch(usuarioSeleccionadoAdminProvider);
  if (seleccionado == null) return false;
  final filtrados = ref.watch(usuariosAdminFiltradosProvider).value;
  if (filtrados == null) return false;
  return !filtrados.any((usuario) => usuario.email == seleccionado.email);
});
