import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';

/// Áreas, equipos y líderes en Supabase. Las tablas, la limpieza de líderes al
/// cambiar un rol y el RLS están versionados en
/// `supabase/areas_equipos_rls.sql`.
class SupabaseOrgStructureRepository implements OrgStructureRepository {
  static const _areas = 'areas';
  static const _teams = 'equipos';
  static const _areaLeaders = 'area_lideres';
  static const _teamLeaders = 'equipo_lideres';

  final SupabaseClient _client;

  SupabaseOrgStructureRepository(this._client);

  SupabaseQueryBuilder _table(String name) =>
      _client.schema('public').from(name);

  @override
  Future<OrgStructure> getStructure() async {
    // Tablas chicas (decenas de filas): entran en una sola página de
    // PostgREST, a diferencia de las tablas de datos.
    final List<List<Map<String, dynamic>>> results;
    try {
      results = await Future.wait([
        _table(_areas).select('id,nombre').order('id'),
        _table(_teams).select('id,area_id,nombre').order('id'),
        _table(_areaLeaders).select('area_id,email'),
        _table(_teamLeaders).select('equipo_id,email'),
      ]);
    } on PostgrestException catch (error) {
      throw FormatException(_errorMessage(error));
    }
    final leadersByArea = _group(results[2], 'area_id');
    final leadersByTeam = _group(results[3], 'equipo_id');

    return OrgStructure(
      areas: [
        for (final row in results[0])
          Area(
            id: row['id'].toString(),
            name: row['nombre']?.toString() ?? '',
            leaders: leadersByArea[row['id'].toString()] ?? const {},
          ),
      ],
      teams: [
        for (final row in results[1])
          Team(
            id: row['id'].toString(),
            areaId: row['area_id'].toString(),
            name: row['nombre']?.toString() ?? '',
            leaders: leadersByTeam[row['id'].toString()] ?? const {},
          ),
      ],
    );
  }

  static Map<String, Set<String>> _group(
    List<Map<String, dynamic>> rows,
    String column,
  ) {
    final grouped = <String, Set<String>>{};
    for (final row in rows) {
      final email = row['email']?.toString() ?? '';
      if (email.isEmpty) continue;
      grouped.putIfAbsent(row[column].toString(), () => {}).add(email);
    }
    return grouped;
  }

  @override
  Future<void> registerMissing(PayrollGaps missing) async {
    if (missing.empty) return;
    await _write(() async {
      if (missing.areas.isNotEmpty) {
        await _table(_areas).insert([
          for (final area in missing.areas) {'nombre': area},
        ]);
      }
      if (missing.teams.isEmpty) return;
      final rows = await _table(_areas).select('id,nombre');
      final idByKey = {
        for (final row in rows)
          OrgStructure.payrollKey(row['nombre']?.toString() ?? ''): row['id'],
      };
      await _table(_teams).insert([
        for (final missing in missing.teams)
          {
            'area_id':
                idByKey[OrgStructure.payrollKey(missing.area)] ??
                (throw FormatException(
                  'No se encontró el área "${missing.area}" para crear el '
                  'equipo "${missing.team}".',
                )),
            'nombre': missing.team,
          },
      ]);
    });
  }

  @override
  Future<void> assignLeadersArea(String areaId, Set<String> emails) =>
      _assignLeaders(_areaLeaders, 'area_id', areaId, emails);

  @override
  Future<void> assignTeamLeaders(String teamId, Set<String> emails) =>
      _assignLeaders(_teamLeaders, 'equipo_id', teamId, emails);

  /// Aplica solo la diferencia con lo que hay en la base: si algo falla a
  /// mitad de camino, no deja al equipo sin ninguno de sus líderes.
  Future<void> _assignLeaders(
    String table,
    String column,
    String id,
    Set<String> emails,
  ) => _write(() async {
    final desired = {
      for (final email in emails)
        if (email.trim().isNotEmpty) OrgStructure.normalizeEmail(email),
    };
    final rows = await _table(table).select('email').eq(column, id);
    final current = {for (final row in rows) row['email'].toString()};
    final remove = current.difference(desired);
    final add = desired.difference(current);
    if (remove.isNotEmpty) {
      await _table(
        table,
      ).delete().eq(column, id).inFilter('email', remove.toList());
    }
    if (add.isNotEmpty) {
      final idValue = int.tryParse(id) ?? id;
      await _table(table).insert([
        for (final email in add) {column: idValue, 'email': email},
      ]);
    }
  });

  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } on PostgrestException catch (error) {
      throw FormatException(_errorMessage(error));
    }
  }

  String _errorMessage(PostgrestException error) {
    debugPrint('estructura ${error.code}: ${error.message}');
    return switch (error.code) {
      '23505' => 'Esa persona ya figura como líder.',
      '42501' => 'No tenés permiso para cambiar áreas, equipos o líderes.',
      '42P01' =>
        'Faltan las tablas de áreas y equipos en la base. Corré '
            'supabase/areas_equipos_rls.sql antes de usar esta versión.',
      _ =>
        'No se pudo guardar el cambio. Intentá nuevamente y, si sigue '
            'pasando, avisale al equipo técnico.',
    };
  }
}
