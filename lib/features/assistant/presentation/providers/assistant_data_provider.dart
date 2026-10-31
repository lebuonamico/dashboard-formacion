import 'dart:async';

import 'package:app_finnegans/features/assistant/domain/assistant_context_service.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/compliance_service_provider.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/employees/presentation/employee_labels.dart';

final aiRealContextProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('IA_CONTEXTO_REAL', defaultValue: true),
);
final assistantContextServiceProvider = Provider<AssistantContextService>(
  (ref) => AssistantContextService(),
);

/// Solo se ejecuta al enviar. El snapshot reutiliza providers y servicios de las
/// pantallas, con sus mismos datos; no cambia filtros ni necesita otra sesión.
final prepareAiContextProvider =
    Provider<Future<AssistantContext> Function(AssistantDestination, String)>(
      (ref) =>
          (destination, question) => _prepare(
            ref,
            destination,
            question,
          ).timeout(const Duration(seconds: 30)),
    );

Future<AssistantContext> _prepare(
  Ref ref,
  AssistantDestination destination,
  String question,
) async {
  final service = ref.read(assistantContextServiceProvider);
  final dynamic = ref.read(aiRealContextProvider);
  final visible = AssistantPeriod(
    year: ref.read(periodFilterProvider).year,
    month: ref.read(periodFilterProvider).month,
    annual: ref.read(periodFilterProvider).scope == PeriodScope.annual,
  );
  final query = service.plan(question, destination, visible);
  final data = <String, Object?>{'notas_alcance': <String>[]};
  final notes = data['notas_alcance'] as List<String>;
  if (!dynamic || query.theme == AssistantTopic.conceptual) {
    data['disponibilidad'] = dynamic
        ? 'Consulta conceptual; no se solicitaron indicadores.'
        : 'Contexto dinámico deshabilitado. No se enviaron indicadores ni ejemplos estáticos.';
    return service.prepare(query, data, dynamic: dynamic);
  }
  if (query.theme == AssistantTopic.import) {
    data['importaciones'] = {
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
    return service.prepare(query, data, dynamic: true);
  }
  if (query.periods.isEmpty) {
    return service.prepare(query, data, dynamic: true);
  }
  if (query.accumulated) {
    if (query.theme == AssistantTopic.general) {
      await _addAccumulated(ref, query, data, service);
    } else {
      notes.add(
        'El acumulado por rango está disponible para el cumplimiento global de la organización desde el Dashboard. No se envió un total global como si correspondiera al área, equipo o perfil seleccionado.',
      );
    }
    return service.prepare(query, data, dynamic: true);
  }
  if (query.theme == AssistantTopic.courses && destination.employeeId == null) {
    final courses = await ref.read(coursesProvider.future);
    data['catalogo'] = service.catalog(courses, question);
    notes.add(
      'No hay perfil seleccionado. Recomendaciones generales, no personalizadas. El catálogo no está historizado por período.',
    );
    return service.prepare(query, data, dynamic: true);
  }

  final results = <Map<String, Object?>>[];
  if (query.evolution) {
    notes.add(
      'La serie enviada es global de la organización; no es una evolución individual ni del equipo o área seleccionados.',
    );
  }
  for (final period in query.periods) {
    final usesGroups =
        query.evolution ||
        query.theme == AssistantTopic.general ||
        query.theme == AssistantTopic.areas ||
        query.theme == AssistantTopic.teams;
    final scope = await _snapshot(ref, period);
    final result = <String, Object?>{'periodo': period.toJson()};
    results.add(result);
    try {
      final hasData = await scope.read(hasTeamPeriodDataProvider.future);
      result['tiene_datos'] = hasData;
      if (!hasData) {
        result['alcance'] =
            'No hay movimientos CRM ni LMS en este período. No evaluar incumplimiento ni inventar ceros.';
        if (query.theme == AssistantTopic.courses) {
          result['catalogo'] = service.catalog(
            await scope.read(coursesProvider.future),
            question,
          );
          notes.add(
            'Sin datos del período para personalizar; se envía catálogo actual sin historial.',
          );
        }
        continue;
      }
      final summary = usesGroups
          ? await scope.read(teamsPeriodSummaryProvider.future)
          : null;
      if (summary != null && summary.employeeCount == 0) {
        result['disponibilidad'] =
            'Hay movimientos pero no colaboradores evaluables; no hay un KPI de cumplimiento para mostrar.';
        continue;
      }
      if (summary != null) result['global'] = _global(summary);
      if (query.evolution) {
        (result['global'] as Map).removeWhere(
          (k, _) => !{
            'completo',
            'colaboradores',
            'horas_validas',
            'horas_objetivo',
            'cumplimiento_pct',
          }.contains(k),
        );
        continue;
      }
      switch (query.theme) {
        case AssistantTopic.general:
          final complianceList = await scope.read(
            dashboardComplianceProvider.future,
          );
          final timeEntries = await scope.read(
            dashboardTimeEntriesProvider.future,
          );
          final months = await scope.read(
            dashboardEvaluatedMonthsProvider.future,
          );
          final kpis = const DashboardKpisService().calculate(
            complianceList: complianceList,
            timeEntries: timeEntries,
            evaluatedMonths: months,
          );
          result['dashboard'] = {
            'completo': true,
            'colaboradores': kpis.employees,
            'capacitandose': kpis.training,
            'horas_declaradas_crm': kpis.declaredHours,
            'meses_evaluados': kpis.evaluatedMonths,
            'ritmo_mensual_hs_por_persona': kpis.monthlyPace,
            'proyeccion_anual_hs_por_persona': kpis.annualProjection,
          };
          if (RegExp(
            r'categor|negocio|blanda|libre|dictad',
          ).hasMatch(service.normalize(question))) {
            result['horas_validas_por_categoria'] = {
              'negocio': summary!.businessHours,
              'blandas': summary.softSkillsHours,
              'libres': summary.explorationHours,
              'dictado': summary.teachingHours,
            };
          }
        case AssistantTopic.areas:
          final areas = await scope.read(areasPeriodSummaryProvider.future);
          var items = areas.areas.toList();
          final q = service.normalize(question);
          final explicit = items
              .where((a) => _mentions(q, a.name, service))
              .toList();
          if (explicit.isNotEmpty) {
            items = explicit;
          } else if (destination.area != null &&
              !RegExp(r'compar|menor|mayor|todas|ranking').hasMatch(q)) {
            items = items
                .where(
                  (a) =>
                      service.normalize(a.name) ==
                      service.normalize(destination.area!),
                )
                .toList();
          }
          if (q.contains('critic')) {
            items = items.where((a) => a.level.label == 'Crítico').toList();
          }
          items.sort(
            (a, b) => q.contains('mayor') || q.contains('mejor')
                ? b.compliancePercentage.compareTo(a.compliancePercentage)
                : a.compliancePercentage.compareTo(b.compliancePercentage),
          );
          result['areas'] = service.selection(
            items
                .map(
                  (a) => <String, Object?>{
                    'area': a.name,
                    'colaboradores': a.memberCount,
                    'personas_en_objetivo': a.membersOnTarget,
                    'horas_validas': a.completedHours,
                    'horas_objetivo': a.targetHours,
                    'cumplimiento_pct': a.compliancePercentage,
                    'estado': a.level.label,
                  },
                )
                .toList(),
            total: items.length,
            criterion:
                'Áreas calculadas; orden por cumplimiento, filtro según pregunta/selección.',
            max: service.totalsOnly(question) ? 0 : 12,
          );
          if (destination.area != null) {
            notes.add(
              'El global corresponde a toda la organización; la lista identifica el área seleccionada cuando aplica.',
            );
          }
        case AssistantTopic.teams:
          var items = summary!.teams.toList();
          final q = service.normalize(question);
          final explicit = items
              .where((e) => _mentions(q, e.name, service))
              .toList();
          final explicitAreas = items
              .map((e) => e.area)
              .where((a) => _mentions(q, a, service))
              .toSet();
          final comparison = RegExp(
            r'compar|otros|resto|todos|que equipos|cuales|ranking|menor|mayor',
          ).hasMatch(q);
          if (destination.team != null) {
            final selected = items
                .where(
                  (e) =>
                      service.normalize(e.name) ==
                          service.normalize(destination.team!) &&
                      service.normalize(e.area) ==
                          service.normalize(destination.area ?? ''),
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
          if (explicit.isNotEmpty) {
            items = explicit;
          } else if (explicitAreas.isNotEmpty) {
            items = items.where((e) => explicitAreas.contains(e.area)).toList();
          } else if (destination.area != null && !comparison) {
            items = items
                .where(
                  (e) =>
                      service.normalize(e.area) ==
                      service.normalize(destination.area!),
                )
                .toList();
            if (destination.team != null) {
              items = items
                  .where(
                    (e) =>
                        service.normalize(e.name) ==
                        service.normalize(destination.team!),
                  )
                  .toList();
            }
          }
          if (q.contains('critic')) {
            items = items
                .where((e) => e.status == TeamStatus.critical)
                .toList();
          } else if (q.contains('riesgo')) {
            items = items.where((e) => e.status == TeamStatus.atRisk).toList();
          } else if (q.contains('en objetivo')) {
            items = items
                .where((e) => e.status == TeamStatus.onTarget)
                .toList();
          }
          if (RegExp(r'menor|mayor|mejor|peor|compar').hasMatch(q)) {
            items.sort(
              (a, b) => q.contains('mayor') || q.contains('mejor')
                  ? b.completionPercentage.compareTo(a.completionPercentage)
                  : a.completionPercentage.compareTo(b.completionPercentage),
            );
          }
          result['equipos'] = service.selection(
            items.map(_team).toList(),
            total: items.length,
            criterion:
                'Estado calculado por EquiposService; filtro de pregunta, prioridad o cumplimiento.',
            max: service.totalsOnly(question) ? 0 : 12,
          );
        case AssistantTopic.person || AssistantTopic.courses:
          final employees = await scope.read(employeesProvider.future);
          final q = service.normalize(question);
          final matches = employees
              .where((e) => _mentions(q, e.fullName, service))
              .toList();
          final employeeId = matches.length == 1
              ? matches.single.employeeId
              : destination.employeeId;
          if (employeeId == null) {
            notes.add(
              'No hay una persona identificada de forma inequívoca. Seleccioná su perfil o indicá el nombre completo. No usar la cuenta autenticada como perfil.',
            );
          } else {
            final detail = await scope.read(
              employeeDetailProvider(employeeId).future,
            );
            if (detail == null) {
              notes.add(
                'No se encontró el perfil seleccionado en la nómina disponible.',
              );
            } else {
              result['perfil_seleccionado'] = service.person(detail.compliance);
              notes.add(
                'El perfil conserva el alcance de su pantalla: usa atributos actuales de nómina y no reconstruye la elegibilidad histórica de Equipos.',
              );
              if (period.annual) {
                notes.add(
                  'El perfil individual usa el objetivo mensual actual ×12 y sus propios filtros, igual que su pantalla; no equivale al acumulado histórico anual de Equipos.',
                );
              }
              if (query.theme == AssistantTopic.courses) {
                result['catalogo'] = service.catalog(
                  await scope.read(coursesProvider.future),
                  question,
                  profile: detail.compliance,
                  completed: detail.completedCourses,
                );
                notes.add(
                  'Catálogo actual, sin historización por período. No se enviaron correo, legajo ni instructor.',
                );
              }
            }
          }
        case AssistantTopic.conceptual || AssistantTopic.import:
          break;
      }
    } catch (_) {
      result['disponibilidad'] =
          'Preparación incompleta: los bloques presentes conservan su alcance. Solo los campos ausentes no están disponibles en esta consulta; no implican ausencia de registros.';
    } finally {
      scope.dispose();
    }
  }
  data['resultados'] = results;
  data['notas_alcance'] = notes.toSet().toList();
  return service.prepare(query, data, dynamic: true);
}

Future<void> _addAccumulated(
  Ref ref,
  AssistantQuery query,
  Map<String, Object?> data,
  AssistantContextService service,
) async {
  String key(AssistantPeriod p) =>
      '${p.year}-${p.month.toString().padLeft(2, '0')}';
  final months = <Map<String, Object?>>[];
  final detail = <Map<String, Object?>>[];
  final evaluated = <TeamsPeriodSummary>[];
  var incomplete = false;
  for (final period in query.periods) {
    final month = <String, Object?>{
      'periodo': key(period),
      'estado': 'no_consultado',
    };
    months.add(month);
    ProviderContainer? scope;
    try {
      scope = await _snapshot(ref, period);
      if (!await scope.read(hasTeamPeriodDataProvider.future)) {
        month['estado'] = 'sin_datos';
        continue;
      }
      final summary = await scope.read(teamsPeriodSummaryProvider.future);
      if (summary.employeeCount == 0) {
        month['estado'] = 'sin_colaboradores_evaluables';
        continue;
      }
      evaluated.add(summary);
      month['estado'] = 'evaluado';
      detail.add({
        'periodo': key(period),
        'horas_validas': summary.completedHours,
        'horas_objetivo': summary.targetHours,
        'cumplimiento_pct': summary.overallCompletion,
      });
    } catch (_) {
      // Un fallo de lectura o de cálculo no equivale a un mes sin registros.
      incomplete = true;
    } finally {
      scope?.dispose();
    }
  }
  final total = !incomplete && evaluated.isNotEmpty
      ? const DashboardKpisService().accumulateCompliance(evaluated)
      : null;
  data['acumulado_solicitado'] = {
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
    'meses': months,
    if (total != null) ...{
      'horas_validas': total.creditedHours,
      'horas_objetivo': total.targetHours,
      'cumplimiento_pct': total.compliance,
    },
  };
  data['desglose_mensual'] = service.selection(
    detail,
    total: detail.length,
    criterion: 'Indicadores mensuales evaluados; el acumulado no se recorta.',
  );
  (data['notas_alcance'] as List<String>).add(
    'El rango incluye ambos extremos. Se acumulan solo meses con datos CRM o LMS y colaboradores evaluables, con elegibilidad histórica y topes mensuales. sin_datos y sin_colaboradores_evaluables se excluyen sin asignarles 0%. no_consultado indica un fallo al obtener o calcular indicadores: impide publicar el total del rango.',
  );
}

Map<String, Object?> _global(TeamsPeriodSummary r) => {
  'completo': true,
  'colaboradores': r.employeeCount,
  'horas_validas': r.completedHours,
  'horas_objetivo': r.targetHours,
  'cumplimiento_pct': r.overallCompletion,
  'equipos': r.teamCount,
  'en_objetivo': r.onTarget,
  'en_riesgo': r.atRisk,
  'criticos': r.critical,
};
Map<String, Object?> _team(TeamOverview e) => {
  'equipo': e.name,
  'area': e.area,
  'integrantes': e.memberCount,
  'personas_en_objetivo': e.membersOnTarget,
  'horas_validas': e.completedHours,
  'horas_objetivo': e.targetHours,
  'cumplimiento_pct': e.completionPercentage,
  'estado': e.status.label,
};
bool _mentions(String q, String name, AssistantContextService s) {
  final n = s.normalize(name);
  return n.length >= 3 && ' $q '.contains(' $n ');
}

Future<ProviderContainer> _snapshot(Ref ref, AssistantPeriod period) async {
  final employeesFuture = ref.read(employeesProvider.future);
  final historyFuture = ref.read(employeeHistoryProvider.future);
  final coursesFuture = ref.read(coursesProvider.future);
  final timeEntriesFuture = ref.read(crmTimeEntriesProvider.future);
  final certificationsFuture = ref.read(lmsCertificationsProvider.future);
  final structureFuture = ref.read(orgStructureProvider.future);
  final scopeFuture = ref.read(userScopeProvider.future);
  final teamsService = ref.read(teamsServiceProvider);
  final complianceServiceFuture = ref.read(complianceServiceProvider.future);
  final session = ref.read(sessionDataProvider);
  final (
    employees,
    history,
    courses,
    timeEntries,
    certifications,
    structure,
    userScope,
    complianceService,
  ) = await (
    employeesFuture,
    historyFuture,
    coursesFuture,
    timeEntriesFuture,
    certificationsFuture,
    structureFuture,
    scopeFuture,
    complianceServiceFuture,
  ).wait;
  return ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      // El contenedor no tiene padre: sin esto armaría otra sesión sin rol y
      // el alcance lo dejaría sin colaboradores.
      sessionDataProvider.overrideWithValue(session),
      orgStructureProvider.overrideWith((_) async => structure),
      userScopeProvider.overrideWith((_) async => userScope),
      employeesProvider.overrideWith((_) async => employees),
      employeeHistoryProvider.overrideWith((_) async => history),
      coursesProvider.overrideWith((_) async => courses),
      crmTimeEntriesProvider.overrideWith((_) async => timeEntries),
      lmsCertificationsProvider.overrideWith((_) async => certifications),
      teamsServiceProvider.overrideWithValue(teamsService),
      complianceServiceProvider.overrideWith((_) async => complianceService),
      periodFilterProvider.overrideWith(
        () => PeriodFilterNotifier(
          PeriodFilter(
            scope: period.annual ? PeriodScope.annual : PeriodScope.monthly,
            month: period.month,
            year: period.year,
          ),
        ),
      ),
      dashboardTimeEntriesProvider.overrideWith(
        (_) async => teamsService.periods.filterTimeEntriesByPeriod(
          timeEntries: timeEntries,
          year: period.year,
          month: period.month,
          isAnnual: period.annual,
        ),
      ),
    ],
  );
}
