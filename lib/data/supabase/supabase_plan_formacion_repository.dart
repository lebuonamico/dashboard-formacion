import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/domain/modelos/plan_formacion.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/repositorios/plan_formacion_repository.dart';

/// Plan de formación en Supabase: una fila por mes de vigencia y seniority.
/// La tabla y su RLS están versionados en `supabase/plan_formacion.sql`.
class SupabasePlanFormacionRepository implements PlanFormacionRepository {
  static const _tabla = 'plan_formacion';
  static const _columnas = {
    TipoCurso.habilidadesDeNegocio: 'negocio',
    TipoCurso.habilidadesBlandas: 'blandas',
    TipoCurso.libresExploracion: 'libres',
    TipoCurso.dictadoCapacitaciones: 'dictado',
  };

  final SupabaseClient _client;

  SupabasePlanFormacionRepository(this._client);

  SupabaseQueryBuilder get _plan => _client.schema('public').from(_tabla);

  @override
  Future<PlanesFormacion> getPlanes() async {
    // Tabla chica (11 filas por versión): entra en una sola página.
    final List<Map<String, dynamic>> filas;
    try {
      filas = await _plan
          .select('vigente_desde,seniority,${_columnas.values.join(',')}')
          .order('vigente_desde');
    } on PostgrestException catch (error) {
      throw FormatException(_mensajeDeError(error, lectura: true));
    }

    final porMes = <String, Map<Seniority, Map<TipoCurso, double>>>{};
    for (final fila in filas) {
      final seniority = _seniority(fila['seniority']);
      porMes.putIfAbsent(
        fila['vigente_desde'].toString(),
        () => {},
      )[seniority] = {
        for (final MapEntry(key: tipo, value: columna) in _columnas.entries)
          tipo: _horas(fila[columna], seniority, tipo),
      };
    }

    // PlanFormacion rechaza una versión a la que le falte una seniority: no se
    // completa con los valores por defecto.
    return PlanesFormacion([
      for (final MapEntry(key: mes, value: horas) in porMes.entries)
        VersionPlanFormacion(
          vigenteDesde: DateTime.parse(mes),
          plan: PlanFormacion(horas),
        ),
    ]);
  }

  @override
  Future<void> guardarVersion(VersionPlanFormacion version) async {
    final vigenteDesde = VersionPlanFormacion.fechaIso(version.vigenteDesde);
    final filas = [
      for (final seniority in Seniority.values)
        {
          'vigente_desde': vigenteDesde,
          'seniority': seniority.name,
          for (final MapEntry(key: tipo, value: columna) in _columnas.entries)
            columna: version.plan.horasRequeridas(seniority)[tipo],
        },
    ];

    final List<Map<String, dynamic>> guardadas;
    try {
      guardadas = await _plan
          .upsert(filas, onConflict: 'vigente_desde,seniority')
          .select('seniority');
    } on PostgrestException catch (error) {
      throw FormatException(_mensajeDeError(error, lectura: false));
    }
    // PostgREST responde éxito aunque no escriba: sin las 11 filas de vuelta,
    // el plan no quedó guardado entero.
    if (guardadas.length != filas.length) {
      throw const FormatException(
        'El plan no se guardó completo. Revisá los permisos sobre '
        'plan_formacion e intentá nuevamente.',
      );
    }
  }

  static Seniority _seniority(Object? valor) {
    final nombre = valor?.toString() ?? '';
    for (final seniority in Seniority.values) {
      if (seniority.name == nombre) return seniority;
    }
    throw FormatException(
      'El plan de formación tiene un seniority desconocido: "$nombre".',
    );
  }

  static double _horas(Object? valor, Seniority seniority, TipoCurso tipo) {
    final horas = valor is num ? valor.toDouble() : double.tryParse('$valor');
    if (horas == null) {
      throw FormatException(
        'El plan de formación no tiene horas de ${tipo.label} para '
        '${seniority.label}.',
      );
    }
    return horas;
  }

  String _mensajeDeError(PostgrestException error, {required bool lectura}) {
    debugPrint('plan_formacion ${error.code}: ${error.message}');
    return switch (error.code) {
      '42P01' || 'PGRST205' =>
        'Falta la tabla del plan de formación en la base. Corré '
            'supabase/plan_formacion.sql antes de usar esta versión.',
      '42501' =>
        lectura
            ? 'No tenés permiso para leer el plan de formación.'
            : 'No tenés permiso para cambiar el plan de formación.',
      _ =>
        lectura
            ? 'No se pudo leer el plan de formación. Intentá nuevamente y, si '
                  'sigue pasando, avisale al equipo técnico.'
            : 'No se pudo guardar el plan de formación. Intentá nuevamente y, '
                  'si sigue pasando, avisale al equipo técnico.',
    };
  }
}
