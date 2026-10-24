import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/repositorios/estructura_repository.dart';

/// Áreas, equipos y líderes en Supabase. Las tablas, la limpieza de líderes al
/// cambiar un rol y el RLS están versionados en
/// `supabase/areas_equipos_rls.sql`.
class SupabaseEstructuraRepository implements EstructuraRepository {
  static const _areas = 'areas';
  static const _equipos = 'equipos';
  static const _areaLideres = 'area_lideres';
  static const _equipoLideres = 'equipo_lideres';

  final SupabaseClient _client;

  SupabaseEstructuraRepository(this._client);

  SupabaseQueryBuilder _tabla(String nombre) =>
      _client.schema('public').from(nombre);

  @override
  Future<EstructuraOrganizacional> getEstructura() async {
    // Tablas chicas (decenas de filas): entran en una sola página de
    // PostgREST, a diferencia de las tablas de datos.
    final List<List<Map<String, dynamic>>> resultados;
    try {
      resultados = await Future.wait([
        _tabla(_areas).select('id,nombre').order('id'),
        _tabla(_equipos).select('id,area_id,nombre').order('id'),
        _tabla(_areaLideres).select('area_id,email'),
        _tabla(_equipoLideres).select('equipo_id,email'),
      ]);
    } on PostgrestException catch (error) {
      throw FormatException(_mensajeDeError(error));
    }
    final lideresPorArea = _agrupar(resultados[2], 'area_id');
    final lideresPorEquipo = _agrupar(resultados[3], 'equipo_id');

    return EstructuraOrganizacional(
      areas: [
        for (final fila in resultados[0])
          Area(
            id: fila['id'].toString(),
            nombre: fila['nombre']?.toString() ?? '',
            lideres: lideresPorArea[fila['id'].toString()] ?? const {},
          ),
      ],
      equipos: [
        for (final fila in resultados[1])
          Equipo(
            id: fila['id'].toString(),
            areaId: fila['area_id'].toString(),
            nombre: fila['nombre']?.toString() ?? '',
            lideres: lideresPorEquipo[fila['id'].toString()] ?? const {},
          ),
      ],
    );
  }

  static Map<String, Set<String>> _agrupar(
    List<Map<String, dynamic>> filas,
    String columna,
  ) {
    final agrupado = <String, Set<String>>{};
    for (final fila in filas) {
      final email = fila['email']?.toString() ?? '';
      if (email.isEmpty) continue;
      agrupado.putIfAbsent(fila[columna].toString(), () => {}).add(email);
    }
    return agrupado;
  }

  @override
  Future<void> registrarFaltantes(FaltantesNomina faltantes) async {
    if (faltantes.vacio) return;
    await _escribir(() async {
      if (faltantes.areas.isNotEmpty) {
        await _tabla(_areas).insert([
          for (final area in faltantes.areas) {'nombre': area},
        ]);
      }
      if (faltantes.equipos.isEmpty) return;
      final filas = await _tabla(_areas).select('id,nombre');
      final idPorClave = {
        for (final fila in filas)
          EstructuraOrganizacional.claveNomina(
            fila['nombre']?.toString() ?? '',
          ): fila['id'],
      };
      await _tabla(_equipos).insert([
        for (final faltante in faltantes.equipos)
          {
            'area_id':
                idPorClave[EstructuraOrganizacional.claveNomina(
                  faltante.area,
                )] ??
                (throw FormatException(
                  'No se encontró el área "${faltante.area}" para crear el '
                  'equipo "${faltante.equipo}".',
                )),
            'nombre': faltante.equipo,
          },
      ]);
    });
  }

  @override
  Future<void> asignarLideresArea(String areaId, Set<String> emails) =>
      _asignarLideres(_areaLideres, 'area_id', areaId, emails);

  @override
  Future<void> asignarLideresEquipo(String equipoId, Set<String> emails) =>
      _asignarLideres(_equipoLideres, 'equipo_id', equipoId, emails);

  /// Aplica solo la diferencia con lo que hay en la base: si algo falla a
  /// mitad de camino, no deja al equipo sin ninguno de sus líderes.
  Future<void> _asignarLideres(
    String tabla,
    String columna,
    String id,
    Set<String> emails,
  ) => _escribir(() async {
    final deseados = {
      for (final email in emails)
        if (email.trim().isNotEmpty)
          EstructuraOrganizacional.normalizarEmail(email),
    };
    final filas = await _tabla(tabla).select('email').eq(columna, id);
    final actuales = {for (final fila in filas) fila['email'].toString()};
    final quitar = actuales.difference(deseados);
    final agregar = deseados.difference(actuales);
    if (quitar.isNotEmpty) {
      await _tabla(
        tabla,
      ).delete().eq(columna, id).inFilter('email', quitar.toList());
    }
    if (agregar.isNotEmpty) {
      final valorId = int.tryParse(id) ?? id;
      await _tabla(tabla).insert([
        for (final email in agregar) {columna: valorId, 'email': email},
      ]);
    }
  });

  Future<void> _escribir(Future<void> Function() accion) async {
    try {
      await accion();
    } on PostgrestException catch (error) {
      throw FormatException(_mensajeDeError(error));
    }
  }

  String _mensajeDeError(PostgrestException error) {
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
