import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_payload_values.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';

/// The data of the context sent to the AI, with the fields it is allowed to
/// see.
class AssistantContextBuilder {
  final AssistantQueryPlanner planner;
  final EmployeeLookupService lookup;

  const AssistantContextBuilder({
    this.planner = const AssistantQueryPlanner(),
    this.lookup = const EmployeeLookupService(),
  });

  AssistantContext prepare(
    AssistantQuery query,
    Map<String, Object?> data, {
    required bool dynamic,
  }) => AssistantContext(
    module: query.destination.module,
    dynamic: dynamic,
    data: {
      'origen':
          'Datos ficticios de demostración cargados en el proyecto académico',
      'pantalla': query.destination.module.payloadValue,
      'tema': query.theme.payloadValue,
      if (query.notes.isNotEmpty) 'notas': query.notes,
      ...data,
    },
  );

  Map<String, Object?> person(EmployeeCompliance compliance) => {
    if (lookup.fullName(compliance.employee).trim().isNotEmpty)
      'nombre': lookup.fullName(compliance.employee).trim(),
    'seniority': compliance.employee.seniority.payloadValue,
    'horas_validas': compliance.totalCreditedHours,
    'horas_declaradas': compliance.totalDeclaredHours,
    'horas_objetivo': compliance.totalRequiredHours,
    'cumplimiento_pct': compliance.totalPercentage,
    'cumple_objetivo': compliance.meetsTarget,
    'categorias': {
      for (final type in CourseCategory.values)
        type.payloadValue: {
          'validas_aplicables': compliance.applicableHours[type]!,
          'objetivo': compliance.requiredHours[type] ?? 0,
        },
    },
  };

  /// Ranking de catálogo, no de KPIs: prioriza coincidencias de tema y categorías
  /// pendientes ya calculadas. Nunca inventa cursos ni envía instructores/IDs.
  Map<String, Object?> catalog(
    List<Course> courses,
    String question, {
    EmployeeCompliance? profile,
    Set<String>? completed,
  }) {
    final q = planner.normalize(question);
    final words = q
        .split(' ')
        .where(
          (p) =>
              p.length > 2 &&
              !{
                'cursos',
                'curso',
                'recomendarias',
                'recomendacion',
                'recomendas',
                'podrias',
                'quiero',
                'recomendar',
                'formacion',
              }.contains(p),
        )
        .toSet();
    final pending = {
      for (final type in CourseCategory.values)
        if (profile != null &&
            profile.applicableHours[type]! < (profile.requiredHours[type] ?? 0))
          type,
    };
    final active = courses.where((c) => c.isActive).toList();
    var candidates = active
        .where((c) => !(completed?.contains(normalizeKey(c.name)) ?? false))
        .toList();
    final category = CourseCategory.values
        .where(
          (type) => switch (type) {
            CourseCategory.softSkills => q.contains('blanda'),
            CourseCategory.businessSkills => q.contains('negocio'),
            CourseCategory.exploration =>
              q.contains('exploracion') || q.contains('libre'),
            CourseCategory.teaching => q.contains('dictado'),
          },
        )
        .firstOrNull;
    if (category != null) {
      candidates = candidates.where((c) => c.category == category).toList();
    }
    int score(Course c) {
      final text = planner.normalize(
        '${c.name} ${c.courseArea} ${c.category.payloadValue}',
      );
      return (pending.contains(c.category) ? 5 : 0) +
          words.where(text.contains).length * 2;
    }

    candidates.sort((a, b) {
      final order = score(b).compareTo(score(a));
      return order != 0 ? order : a.name.compareTo(b.name);
    });
    return selection(
        candidates
            .map(
              (c) => <String, Object?>{
                'curso': c.name,
                'categoria': c.category.payloadValue,
                'rol': c.category == CourseCategory.teaching
                    ? 'instructor'
                    : 'participante',
                'horas': c.workloadHours,
              },
            )
            .toList(),
        total: candidates.length,
        criterion: profile == null
            ? 'Catálogo activo por afinidad textual; falta perfil para personalizar.'
            : 'Catálogo activo; prioriza categorías pendientes del perfil calculado. No garantiza cubrir todo el objetivo.',
        max: planner.totalsOnly(question) ? 0 : 12,
      )
      ..['activos_catalogo'] = active.length
      ..['finalizados_excluidos'] = completed != null
      ..['perfil_disponible'] = profile != null;
  }

  Map<String, Object?> selection(
    List<Map<String, Object?>> items, {
    required int total,
    required String criterion,
    int max = 12,
  }) => {
    'total_coincidencias': total,
    'enviados': items.length > max ? max : items.length,
    'criterio': criterion,
    'seleccion_parcial': (items.length > max ? max : items.length) < total,
    if (items.length > max) 'limitado_por': ['cantidad'],
    'items': items.take(max).toList(),
  };
}
