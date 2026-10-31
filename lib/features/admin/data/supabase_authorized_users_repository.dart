import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/auth/data/user_role_codes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/features/admin/domain/authorized_user.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';

class SupabaseAuthorizedUsersRepository implements AuthorizedUsersRepository {
  static const _table = 'usuarios_autorizados';
  static const _columns = 'email,rol,activo,ff_alta,ff_bloqueo,ff_eliminar';

  final SupabaseClient _client;

  SupabaseAuthorizedUsersRepository(this._client);

  @override
  Future<List<AuthorizedUser>> getUsers() async {
    final rows = await _client
        .schema('public')
        .from(_table)
        .select(_columns)
        .order('email', ascending: true);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> create(AuthorizedUser user) async {
    try {
      await _client.schema('public').from(_table).insert({
        'email': normalizeLoose(user.email),
        'rol': userRoleToDb(user.role),
        'activo': user.isActive,
        'ff_alta': user.createdAt?.toUtc().toIso8601String(),
        'ff_bloqueo': user.blockedAt?.toUtc().toIso8601String(),
        'ff_eliminar': user.deletedAt?.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      throw FormatException(_errorMessage(error));
    }
  }

  @override
  Future<void> save(AuthorizedUser user) async {
    final List<dynamic> affected;
    try {
      affected = await _client
          .schema('public')
          .from(_table)
          .update({
            'rol': userRoleToDb(user.role),
            'activo': user.isActive,
            'ff_bloqueo': user.blockedAt?.toUtc().toIso8601String(),
            'ff_eliminar': user.deletedAt?.toUtc().toIso8601String(),
          })
          .eq('email', normalizeLoose(user.email))
          .select('email');
    } on PostgrestException catch (error) {
      throw FormatException(_errorMessage(error));
    }
    if (affected.isEmpty) {
      throw const FormatException(
        'El usuario ya no existe o no tenés permiso para modificarlo.',
      );
    }
  }

  String _errorMessage(PostgrestException error) {
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

  AuthorizedUser _fromRow(Map<String, dynamic> row) => AuthorizedUser(
    email: normalizeLoose(row['email']?.toString() ?? ''),
    role: userRoleFromDb(row['rol']?.toString() ?? ''),
    isActive: row['activo'] == true,
    createdAt: _date(row['ff_alta']),
    blockedAt: _date(row['ff_bloqueo']),
    deletedAt: _date(row['ff_eliminar']),
  );

  static DateTime? _date(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }
}
