import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/areas/domain/areas_service.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_data.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_payload_values.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_period_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_trend_service.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope_service.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:app_finnegans/features/teams/domain/teams_service.dart';

typedef AssistantDataLoader = Future<AssistantData> Function();

/// The data of the context sent to the AI, with the fields it is allowed to
/// see. Each period is calculated with the same services as its screen.
class AssistantContextBuilder {
  static const _importRules = {
    'orden': ['Nómina', 'Cursos', 'Horas CRM', 'Finalizaciones LMS'],
    'nomina_cursos':
        'Snapshot por archivo: activa presentes e inactiva ausentes sin borrado físico; no aceptar una foto vacía.',
    'crm':
        'UPSERT por transacción; resuelve curso por nombre normalizado; no elimina ausentes.',
    'lms':
        'UPSERT por legajo+curso; no elimina ausentes ni interpreta ausencia como no finalización.',
    'auditoria':
        'Registra resultado y errores; luego refresca providers. Un fallo de refresh no implica que no se hayan guardado los datos.',
    'limite':
        'Sin contenido de archivos ni historial de importaciones. No puede ejecutar cargas.',
  };

  static const _evolutionFields = {
    'completo',
    'colaboradores',
    'horas_validas',
    'horas_objetivo',
    'cumplimiento_pct',
  };

  final AssistantQueryPlanner planner;
  final CompliancePeriodService periods;
  final TeamsService teams;
  final AreasService areas;
  final DashboardKpisService kpis;
  final DashboardTrendService trend;
  final UserScopeService scopes;
  final EmployeeLookupService lookup;

  AssistantContextBuilder({
    this.planner = const AssistantQueryPlanner(),
    this.periods = const CompliancePeriodService(),
    this.teams = const TeamsService(),
    this.areas = const AreasService(),
    DashboardKpisService? kpis,
    this.trend = const DashboardTrendService(),
    this.scopes = const UserScopeService(),
    this.lookup = const EmployeeLookupService(),
  }) : kpis = kpis ?? DashboardKpisService();

  /// [loadData] is only called by the queries that send indicators.
  Future<AssistantContext> build(
    AssistantQuery query, {
    required bool dynamic,
    required AssistantDataLoader loadData,
  }) async {
    final notes = <String>[];
    final data = <String, Object?>{'notas_alcance': notes};
    if (!dynamic || query.theme == AssistantTopic.conceptual) {
      data['disponibilidad'] = dynamic
          ? 'Consulta conceptual; no se solicitaron indicadores.'
          : 'Contexto dinámico deshabilitado. No se enviaron indicadores ni ejemplos estáticos.';
      return _prepare(query, data, dynamic: dynamic);
    }
    if (query.theme == AssistantTopic.import) {
      data['importaciones'] = _importRules;
      return _prepare(query, data, dynamic: true);
    }
    if (query.periods.isEmpty) return _prepare(query, data, dynamic: true);
    if (query.accumulated) {
      if (query.theme == AssistantTopic.general) {
        data.addAll(await _accumulated(query, loadData));
        notes.add(
          'El rango incluye ambos extremos. Se acumulan solo meses con datos CRM o LMS y colaboradores evaluables, con elegibilidad histórica y topes mensuales. sin_datos y sin_colaboradores_evaluables se excluyen sin asignarles 0%. no_consultado indica un fallo al obtener o calcular indicadores: impide publicar el total del rango.',
        );
      } else {
        notes.add(
          'El acumulado por rango está disponible para el cumplimiento global de la organización desde el Dashboard. No se envió un total global como si correspondiera al área, equipo o perfil seleccionado.',
        );
      }
      return _prepare(query, data, dynamic: true);
    }
    if (query.theme == AssistantTopic.courses &&
        query.destination.employeeId == null) {
      data['catalogo'] = _catalog((await loadData()).courses, query.question);
      notes.add(
        'No hay perfil seleccionado. Recomendaciones generales, no personalizadas. El catálogo no está historizado por período.',
      );
      return _prepare(query, data, dynamic: true);
    }

    if (query.evolution) {
      notes.add(
        'La serie enviada es global de la organización; no es una evolución individual ni del equipo o área seleccionados.',
      );
    }
    final source = await loadData();
    data['resultados'] = [
      for (final period in query.periods)
        _periodResult(query, period, source, notes),
    ];
    data['notas_alcance'] = notes.toSet().toList();
    return _prepare(query, data, dynamic: true);
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

  AssistantContext _prepare(
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

  PeriodFilter _filter(AssistantPeriod period) => PeriodFilter(
    scope: period.annual ? PeriodScope.annual : PeriodScope.monthly,
    month: period.month,
    year: period.year,
  );

  bool _hasData(AssistantData data, PeriodFilter period) =>
      periods.hasDataInPeriod(
        timeEntries: data.timeEntries,
        certifications: data.certifications,
        year: period.year,
        month: period.month,
        isAnnual: period.scope == PeriodScope.annual,
      );

  List<EmployeeCompliance> _compliance(
    AssistantData data,
    PeriodFilter period,
  ) => periods.calculateForPeriod(
    employees: data.employees,
    history: data.history,
    courses: data.courses,
    timeEntries: data.timeEntries,
    certifications: data.certifications,
    period: period,
    complianceService: data.complianceService,
    includeEmployee: scopes.employeeFilter(data.scope),
  );

  Map<String, Object?> _periodResult(
    AssistantQuery query,
    AssistantPeriod period,
    AssistantData data,
    List<String> notes,
  ) {
    final result = <String, Object?>{'periodo': period.toJson()};
    final filter = _filter(period);
    try {
      final hasData = _hasData(data, filter);
      result['tiene_datos'] = hasData;
      if (!hasData) {
        result['alcance'] =
            'No hay movimientos CRM ni LMS en este período. No evaluar incumplimiento ni inventar ceros.';
        if (query.theme == AssistantTopic.courses) {
          result['catalogo'] = _catalog(data.courses, query.question);
          notes.add(
            'Sin datos del período para personalizar; se envía catálogo actual sin historial.',
          );
        }
        return result;
      }
      late final compliance = _compliance(data, filter);
      final usesGroups =
          query.evolution ||
          query.theme == AssistantTopic.general ||
          query.theme == AssistantTopic.areas ||
          query.theme == AssistantTopic.teams;
      final summary = usesGroups
          ? teams.periodSummary(compliance, filter)
          : null;
      if (summary != null && summary.employeeCount == 0) {
        result['disponibilidad'] =
            'Hay movimientos pero no colaboradores evaluables; no hay un KPI de cumplimiento para mostrar.';
        return result;
      }
      if (summary != null) result['global'] = _global(summary);
      if (query.evolution) {
        (result['global'] as Map).removeWhere(
          (key, _) => !_evolutionFields.contains(key),
        );
        return result;
      }
      switch (query.theme) {
        case AssistantTopic.general:
          result.addAll(_general(query, data, filter, compliance, summary!));
        case AssistantTopic.areas:
          result['areas'] = _areas(query, compliance, notes);
        case AssistantTopic.teams:
          result.addAll(_teams(query, summary!, notes));
        case AssistantTopic.person || AssistantTopic.courses:
          result.addAll(_person(query, period, data, filter, notes));
        case AssistantTopic.conceptual || AssistantTopic.import:
          break;
      }
    } catch (_) {
      result['disponibilidad'] =
          'Preparación incompleta: los bloques presentes conservan su alcance. Solo los campos ausentes no están disponibles en esta consulta; no implican ausencia de registros.';
    }
    return result;
  }

  Map<String, Object?> _general(
    AssistantQuery query,
    AssistantData data,
    PeriodFilter period,
    List<EmployeeCompliance> compliance,
    TeamsPeriodSummary summary,
  ) {
    final dashboard = kpis.calculate(
      complianceList: compliance,
      timeEntries: trend.timeEntriesInPeriod(data.timeEntries, period),
      evaluatedMonths: trend.evaluatedMonths(
        timeEntries: data.timeEntries,
        certifications: data.certifications,
        period: period,
      ),
    );
    return {
      'dashboard': {
        'completo': true,
        'colaboradores': dashboard.employees,
        'capacitandose': dashboard.training,
        'horas_declaradas_crm': dashboard.declaredHours,
        'meses_evaluados': dashboard.evaluatedMonths,
        'ritmo_mensual_hs_por_persona': dashboard.monthlyPace,
        'proyeccion_anual_hs_por_persona': dashboard.annualProjection,
      },
      if (RegExp(
        r'categor|negocio|blanda|libre|dictad',
      ).hasMatch(planner.normalize(query.question)))
        'horas_validas_por_categoria': {
          'negocio': summary.businessHours,
          'blandas': summary.softSkillsHours,
          'libres': summary.explorationHours,
          'dictado': summary.teachingHours,
        },
    };
  }

  Map<String, Object?> _areas(
    AssistantQuery query,
    List<EmployeeCompliance> compliance,
    List<String> notes,
  ) {
    final destination = query.destination;
    final q = planner.normalize(query.question);
    final all = areas.buildPeriodSummary(compliance).areas;
    final explicit = all.where((area) => _mentions(q, area.name)).toList();
    final selected = explicit.isNotEmpty
        ? explicit
        : destination.area != null &&
              !RegExp(r'compar|menor|mayor|todas|ranking').hasMatch(q)
        ? all
              .where(
                (area) =>
                    planner.normalize(area.name) ==
                    planner.normalize(destination.area!),
              )
              .toList()
        : all.toList();
    final items = q.contains('critic')
        ? selected
              .where((area) => area.level == ComplianceLevel.critical)
              .toList()
        : selected;
    items.sort(
      (a, b) => q.contains('mayor') || q.contains('mejor')
          ? b.compliancePercentage.compareTo(a.compliancePercentage)
          : a.compliancePercentage.compareTo(b.compliancePercentage),
    );
    if (destination.area != null) {
      notes.add(
        'El global corresponde a toda la organización; la lista identifica el área seleccionada cuando aplica.',
      );
    }
    return selection(
      items
          .map(
            (area) => <String, Object?>{
              'area': area.name,
              'colaboradores': area.memberCount,
              'personas_en_objetivo': area.membersOnTarget,
              'horas_validas': area.completedHours,
              'horas_objetivo': area.targetHours,
              'cumplimiento_pct': area.compliancePercentage,
              'estado': area.level.payloadValue,
            },
          )
          .toList(),
      total: items.length,
      criterion:
          'Áreas calculadas; orden por cumplimiento, filtro según pregunta/selección.',
      max: planner.totalsOnly(query.question) ? 0 : 12,
    );
  }

  Map<String, Object?> _teams(
    AssistantQuery query,
    TeamsPeriodSummary summary,
    List<String> notes,
  ) {
    final destination = query.destination;
    final q = planner.normalize(query.question);
    final all = summary.teams;
    bool sameName(String a, String b) =>
        planner.normalize(a) == planner.normalize(b);
    final explicit = all.where((team) => _mentions(q, team.name)).toList();
    final explicitAreas = all
        .map((team) => team.area)
        .where((area) => _mentions(q, area))
        .toSet();
    final comparison = RegExp(
      r'compar|otros|resto|todos|que equipos|cuales|ranking|menor|mayor',
    ).hasMatch(q);
    final result = <String, Object?>{};
    if (destination.team != null) {
      final selected = all
          .where(
            (team) =>
                sameName(team.name, destination.team!) &&
                sameName(team.area, destination.area ?? ''),
          )
          .firstOrNull;
      if (selected != null) {
        result['equipo_seleccionado'] = _team(selected);
      } else {
        notes.add(
          'El equipo seleccionado no tiene integrantes evaluables en este período; no implica que no exista en la base.',
        );
      }
    }
    final inScope = explicit.isNotEmpty
        ? explicit
        : explicitAreas.isNotEmpty
        ? all.where((team) => explicitAreas.contains(team.area)).toList()
        : destination.area != null && !comparison
        ? all
              .where((team) => sameName(team.area, destination.area!))
              .where(
                (team) =>
                    destination.team == null ||
                    sameName(team.name, destination.team!),
              )
              .toList()
        : all.toList();
    final status = q.contains('critic')
        ? TeamStatus.critical
        : q.contains('riesgo')
        ? TeamStatus.atRisk
        : q.contains('en objetivo')
        ? TeamStatus.onTarget
        : null;
    final items = status == null
        ? inScope
        : inScope.where((team) => team.status == status).toList();
    if (RegExp(r'menor|mayor|mejor|peor|compar').hasMatch(q)) {
      items.sort(
        (a, b) => q.contains('mayor') || q.contains('mejor')
            ? b.completionPercentage.compareTo(a.completionPercentage)
            : a.completionPercentage.compareTo(b.completionPercentage),
      );
    }
    result['equipos'] = selection(
      items.map(_team).toList(),
      total: items.length,
      criterion:
          'Estado calculado por EquiposService; filtro de pregunta, prioridad o cumplimiento.',
      max: planner.totalsOnly(query.question) ? 0 : 12,
    );
    return result;
  }

  Map<String, Object?> _person(
    AssistantQuery query,
    AssistantPeriod period,
    AssistantData data,
    PeriodFilter filter,
    List<String> notes,
  ) {
    final q = planner.normalize(query.question);
    final matches = data.employees
        .where((employee) => _mentions(q, lookup.fullName(employee)))
        .toList();
    final employeeId = matches.length == 1
        ? matches.single.employeeId
        : query.destination.employeeId;
    if (employeeId == null) {
      notes.add(
        'No hay una persona identificada de forma inequívoca. Seleccioná su perfil o indicá el nombre completo. No usar la cuenta autenticada como perfil.',
      );
      return const {};
    }
    final employee = data.employees
        .where((employee) => employee.employeeId == employeeId)
        .firstOrNull;
    if (employee == null) {
      notes.add(
        'No se encontró el perfil seleccionado en la nómina disponible.',
      );
      return const {};
    }
    // The same calculation as the profile screen, so both say the same.
    final profile = periods.employeeProfileCompliance(
      employee: employee,
      courses: data.courses,
      timeEntries: data.timeEntries,
      certifications: data.certifications,
      period: filter,
      complianceService: data.complianceService,
    );
    notes.add(
      'El perfil conserva el alcance de su pantalla: usa atributos actuales de nómina y no reconstruye la elegibilidad histórica de Equipos.',
    );
    if (period.annual) {
      notes.add(
        'El perfil individual anual suma solo sus meses con datos desde el ingreso, cada uno con el plan vigente en ese mes, igual que su pantalla; no equivale al acumulado histórico anual de Equipos.',
      );
    }
    if (query.theme != AssistantTopic.courses) {
      return {'perfil_seleccionado': _profile(profile)};
    }
    final completed = data.certifications
        .where((item) => item.employeeId == employeeId && item.isCompleted)
        .map((item) => normalizeKey(item.courseName))
        .toSet();
    notes.add(
      'Catálogo actual, sin historización por período. No se enviaron correo, legajo ni instructor.',
    );
    return {
      'perfil_seleccionado': _profile(profile),
      'catalogo': _catalog(
        data.courses,
        query.question,
        profile: profile,
        completed: completed,
      ),
    };
  }

  Future<Map<String, Object?>> _accumulated(
    AssistantQuery query,
    AssistantDataLoader loadData,
  ) async {
    String key(AssistantPeriod period) =>
        '${period.year}-${period.month.toString().padLeft(2, '0')}';
    final months = [
      for (final period in query.periods)
        (key: key(period), evaluation: await _evaluateMonth(period, loadData)),
    ];
    final evaluated = [
      for (final month in months)
        if (month.evaluation.summary case final summary?)
          (key: month.key, summary: summary),
    ];
    final incomplete = months.any((month) => month.evaluation.failed);
    final total = !incomplete && evaluated.isNotEmpty
        ? kpis.accumulateCompliance(evaluated.map((month) => month.summary))
        : null;
    final detail = [
      for (final month in evaluated)
        <String, Object?>{
          'periodo': month.key,
          'horas_validas': month.summary.completedHours,
          'horas_objetivo': month.summary.targetHours,
          'cumplimiento_pct': month.summary.overallCompletion,
        },
    ];
    return {
      'acumulado_solicitado': {
        'alcance': 'global_organizacion',
        'desde': key(query.periods.first),
        'hasta': key(query.periods.last),
        'completo': !incomplete,
        'estado': incomplete
            ? 'incompleto'
            : total == null
            ? 'sin_meses_evaluables'
            : 'disponible',
        'meses_solicitados': months.length,
        'meses_evaluados': evaluated.length,
        'meses': [
          for (final month in months)
            {'periodo': month.key, 'estado': month.evaluation.status},
        ],
        if (total != null) ...{
          'horas_validas': total.creditedHours,
          'horas_objetivo': total.targetHours,
          'cumplimiento_pct': total.compliance,
        },
      },
      'desglose_mensual': selection(
        detail,
        total: detail.length,
        criterion:
            'Indicadores mensuales evaluados; el acumulado no se recorta.',
      ),
    };
  }

  /// A failure to read or calculate is not a month without records.
  Future<({String status, TeamsPeriodSummary? summary, bool failed})>
  _evaluateMonth(AssistantPeriod period, AssistantDataLoader loadData) async {
    try {
      final data = await loadData();
      final filter = _filter(period);
      if (!_hasData(data, filter)) {
        return (status: 'sin_datos', summary: null, failed: false);
      }
      final summary = teams.periodSummary(_compliance(data, filter), filter);
      if (summary.employeeCount == 0) {
        return (
          status: 'sin_colaboradores_evaluables',
          summary: null,
          failed: false,
        );
      }
      return (status: 'evaluado', summary: summary, failed: false);
    } catch (_) {
      return (status: 'no_consultado', summary: null, failed: true);
    }
  }

  Map<String, Object?> _global(TeamsPeriodSummary summary) => {
    'completo': true,
    'colaboradores': summary.employeeCount,
    'horas_validas': summary.completedHours,
    'horas_objetivo': summary.targetHours,
    'cumplimiento_pct': summary.overallCompletion,
    'equipos': summary.teamCount,
    'en_objetivo': summary.onTarget,
    'en_riesgo': summary.atRisk,
    'criticos': summary.critical,
  };

  Map<String, Object?> _team(TeamOverview team) => {
    'equipo': team.name,
    'area': team.area,
    'integrantes': team.memberCount,
    'personas_en_objetivo': team.membersOnTarget,
    'horas_validas': team.completedHours,
    'horas_objetivo': team.targetHours,
    'cumplimiento_pct': team.completionPercentage,
    'estado': team.status.payloadValue,
  };

  bool _mentions(String question, String name) {
    final normalized = planner.normalize(name);
    return normalized.length >= 3 && ' $question '.contains(' $normalized ');
  }

  Map<String, Object?> _profile(EmployeeCompliance compliance) => {
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

  /// A catalog ranking, not a KPI: it favours topic matches and the pending
  /// categories of the profile. It never invents courses nor sends
  /// instructors or IDs.
  Map<String, Object?> _catalog(
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
    final candidates = active
        .where((c) => !(completed?.contains(normalizeKey(c.name)) ?? false))
        .where((c) => category == null || c.category == category)
        .toList();
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
}
