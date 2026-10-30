import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';

/// Plan de formación en Supabase: una fila por mes de vigencia y seniority.
/// La tabla y su RLS están versionados en `supabase/plan_formacion.sql`.
class SupabaseTrainingPlanRepository implements TrainingPlanRepository {
  static const _table = 'plan_formacion';
  static const _columns = {
    CourseCategory.businessSkills: 'negocio',
    CourseCategory.softSkills: 'blandas',
    CourseCategory.exploration: 'libres',
    CourseCategory.teaching: 'dictado',
  };

  final SupabaseClient _client;

  SupabaseTrainingPlanRepository(this._client);

  SupabaseQueryBuilder get _plan => _client.schema('public').from(_table);

  @override
  Future<TrainingPlanHistory> getPlans() async {
    // Tabla chica (11 filas por versión): entra en una sola página.
    final List<Map<String, dynamic>> rows;
    try {
      rows = await _plan
          .select('vigente_desde,seniority,${_columns.values.join(',')}')
          .order('vigente_desde');
    } on PostgrestException catch (error) {
      throw FormatException(_errorMessage(error, read: true));
    }

    final byMonth = <String, Map<Seniority, Map<CourseCategory, double>>>{};
    for (final row in rows) {
      final seniority = _seniority(row['seniority']);
      byMonth.putIfAbsent(
        row['vigente_desde'].toString(),
        () => {},
      )[seniority] = {
        for (final MapEntry(key: type, value: column) in _columns.entries)
          type: _hours(row[column], seniority, type),
      };
    }

    // PlanFormacion rechaza una versión a la que le falte una seniority: no se
    // completa con los valores por defecto.
    return TrainingPlanHistory([
      for (final MapEntry(key: month, value: hours) in byMonth.entries)
        TrainingPlanVersion(
          validFrom: DateTime.parse(month),
          plan: TrainingPlan(hours),
        ),
    ]);
  }

  @override
  Future<void> saveVersion(TrainingPlanVersion version) async {
    final validFrom = TrainingPlanVersion.dateIso(version.validFrom);
    final rows = [
      for (final seniority in Seniority.values)
        {
          'vigente_desde': validFrom,
          'seniority': seniority.name,
          for (final MapEntry(key: type, value: column) in _columns.entries)
            column: version.plan.requiredHours(seniority)[type],
        },
    ];

    final List<Map<String, dynamic>> saved;
    try {
      saved = await _plan
          .upsert(rows, onConflict: 'vigente_desde,seniority')
          .select('seniority');
    } on PostgrestException catch (error) {
      throw FormatException(_errorMessage(error, read: false));
    }
    // PostgREST responde éxito aunque no escriba: sin las 11 filas de vuelta,
    // el plan no quedó guardado entero.
    if (saved.length != rows.length) {
      throw const FormatException(
        'El plan no se guardó completo. Revisá los permisos sobre '
        'plan_formacion e intentá nuevamente.',
      );
    }
  }

  static Seniority _seniority(Object? value) {
    final name = value?.toString() ?? '';
    for (final seniority in Seniority.values) {
      if (seniority.name == name) return seniority;
    }
    throw FormatException(
      'El plan de formación tiene un seniority desconocido: "$name".',
    );
  }

  static double _hours(
    Object? value,
    Seniority seniority,
    CourseCategory type,
  ) {
    final hours = value is num ? value.toDouble() : double.tryParse('$value');
    if (hours == null) {
      throw FormatException(
        'El plan de formación no tiene horas de ${type.label} para '
        '${seniority.label}.',
      );
    }
    return hours;
  }

  String _errorMessage(PostgrestException error, {required bool read}) {
    debugPrint('plan_formacion ${error.code}: ${error.message}');
    return switch (error.code) {
      '42P01' || 'PGRST205' =>
        'Falta la tabla del plan de formación en la base. Corré '
            'supabase/plan_formacion.sql antes de usar esta versión.',
      '42501' =>
        read
            ? 'No tenés permiso para leer el plan de formación.'
            : 'No tenés permiso para cambiar el plan de formación.',
      _ =>
        read
            ? 'No se pudo leer el plan de formación. Intentá nuevamente y, si '
                  'sigue pasando, avisale al equipo técnico.'
            : 'No se pudo guardar el plan de formación. Intentá nuevamente y, '
                  'si sigue pasando, avisale al equipo técnico.',
    };
  }
}
