import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';
import 'package:app_finnegans/domain/repositorios/usuarios_autorizados_repository.dart';

class SupabaseUsuariosAutorizadosRepository
    implements UsuariosAutorizadosRepository {
  static const _tabla = 'usuarios_autorizados';
  static const _columnas = 'email,rol,activo,ff_alta,ff_bloqueo,ff_eliminar';

  final SupabaseClient _client;

  SupabaseUsuariosAutorizadosRepository(this._client);

  @override
  Future<List<UsuarioAutorizado>> getUsuarios() async {
    final rows = await _client
        .schema('public')
        .from(_tabla)
        .select(_columnas)
        .order('email', ascending: true);
    return rows.map(_desdeFila).toList();
  }

  @override
  Future<void> crear(UsuarioAutorizado usuario) async {
    try {
      await _client.schema('public').from(_tabla).insert({
        'email': usuario.email,
        'rol': usuario.rol,
        'activo': usuario.activo,
        'ff_alta': usuario.ffAlta?.toUtc().toIso8601String(),
        'ff_bloqueo': usuario.ffBloqueo?.toUtc().toIso8601String(),
        'ff_eliminar': usuario.ffEliminar?.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      throw FormatException(_mensajeDeError(error));
    }
  }

  @override
  Future<void> guardar(UsuarioAutorizado usuario) async {
    final List<dynamic> afectadas;
    try {
      afectadas = await _client
          .schema('public')
          .from(_tabla)
          .update({
            'rol': usuario.rol,
            'activo': usuario.activo,
            'ff_bloqueo': usuario.ffBloqueo?.toUtc().toIso8601String(),
            'ff_eliminar': usuario.ffEliminar?.toUtc().toIso8601String(),
          })
          .eq('email', usuario.email)
          .select('email');
    } on PostgrestException catch (error) {
      throw FormatException(_mensajeDeError(error));
    }
    if (afectadas.isEmpty) {
      throw const FormatException(
        'El usuario ya no existe o no tenés permiso para modificarlo.',
      );
    }
  }

  String _mensajeDeError(PostgrestException error) {
    debugPrint('usuarios_autorizados ${error.code}: ${error.message}');
    return switch (error.code) {
      '23505' =>
        'Ya existe un usuario con ese email. '
            'Si fue eliminado, restauralo desde la lista.',
      '42501' => 'No tenés permiso para administrar usuarios.',
      _ =>
        'No se pudo guardar el usuario. Intentá nuevamente y, si sigue '
            'pasando, avisale al equipo técnico.',
    };
  }

  UsuarioAutorizado _desdeFila(Map<String, dynamic> fila) => UsuarioAutorizado(
    email: fila['email']?.toString() ?? '',
    rol: fila['rol']?.toString() ?? '',
    activo: fila['activo'] == true,
    ffAlta: _fecha(fila['ff_alta']),
    ffBloqueo: _fecha(fila['ff_bloqueo']),
    ffEliminar: _fecha(fila['ff_eliminar']),
  );

  static DateTime? _fecha(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}
