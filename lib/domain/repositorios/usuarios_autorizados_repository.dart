import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';

abstract interface class UsuariosAutorizadosRepository {
  Future<List<UsuarioAutorizado>> getUsuarios();

  Future<void> crear(UsuarioAutorizado usuario);

  Future<void> guardar(UsuarioAutorizado usuario);
}
