import 'package:app_finnegans/features/reports/domain/print_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_records_repository.dart';
import 'package:app_finnegans/features/imports/domain/import_audit_service.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/core/data/supabase_mapping.dart';
import 'package:app_finnegans/features/imports/data/supabase_import_records_repository.dart';
import 'package:app_finnegans/core/data/supabase_repositories.dart';
import 'package:app_finnegans/features/admin/data/supabase_authorized_users_repository.dart';
import 'package:app_finnegans/features/org_structure/data/supabase_org_structure_repository.dart';
import 'package:app_finnegans/features/training_plan/data/supabase_training_plan_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';
import 'package:app_finnegans/features/admin/domain/authorized_users_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/reports/data/printing_print_repository.dart';
import 'package:app_finnegans/core/legacy/local_repositories.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
final supabaseMappingsProvider = Provider<SupabaseMappings>(
  (ref) => SupabaseMappings(
    employees: SupabaseTableMapping(
      table: 'empleados',
      conflictFields: ['legajo'],
      columns: {
        'legajo': 'legajo',
        'mail': 'correo',
        'nombre': 'nombre',
        'apellido': 'apellido',
        'seniority': 'seniority',
        'area': 'sector',
        'equipo': 'equipo_general',
        'gerente': 'gerente',
        'fechaIngreso': 'fecha_ingreso',
        'activo': 'activo',
      },
    ),
    courses: SupabaseTableMapping(
      table: 'cursos',
      conflictFields: ['id'],
      columns: {
        'id': 'id_curso',
        'nombre': 'nombre',
        'clasificacion': 'clasificacion',
        'cargaHorariaHs': 'carga_horaria',
        'activo': 'activo',
      },
    ),
    hours: SupabaseTableMapping(
      table: 'horas_capacitacion',
      conflictFields: ['id'],
      columns: {
        'id': 'transaccion_id',
        'empleadoLegajo': 'legajo',
        'cursoId': 'curso_id',
        'fecha': 'fecha',
        'caso': 'caso',
        'descripcionCurso': 'descripcion_curso',
        'clasificacion': 'clasificacion',
        'proyecto': 'proyecto',
        'proyectoItem': 'proyecto_item',
        'horasTotales': 'horas_totales',
        'descripcion': 'descripcion',
      },
    ),
    completions: SupabaseTableMapping(
      table: 'finalizaciones_cursos',
      conflictFields: ['legajo', 'cursoId'],
      columns: {
        'legajo': 'legajo',
        'cursoId': 'curso_id',
        'finalizoCurso': 'finalizo',
        'fechaFinalizacion': 'fecha_finalizacion',
      },
    ),
  ),
);

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  return SupabaseConfig.enabled
      ? SupabaseEmployeesRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(supabaseMappingsProvider).employees,
        )
      : LocalEmployeesRepository();
});

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  // El repositorio guarda el catálogo leído: otra sesión lo vuelve a leer.
  ref.watch(sessionDataProvider);
  return SupabaseConfig.enabled
      ? SupabaseCoursesRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(supabaseMappingsProvider).courses,
        )
      : LocalCoursesRepository();
});

final crmTimeEntriesRepositoryProvider = Provider<CrmTimeEntriesRepository>((
  ref,
) {
  return SupabaseConfig.enabled
      ? SupabaseCrmTimeEntriesRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(supabaseMappingsProvider).hours,
          ref.watch(coursesRepositoryProvider),
        )
      : LocalCrmTimeEntriesRepository();
});

final lmsCertificationsRepositoryProvider =
    Provider<LmsCertificationsRepository>((ref) {
      return SupabaseConfig.enabled
          ? SupabaseLmsCertificationsRepository(
              ref.watch(supabaseClientProvider),
              ref.watch(supabaseMappingsProvider).completions,
              ref.watch(coursesRepositoryProvider),
            )
          : LocalLmsCertificationsRepository();
    });

final trainingPlanRepositoryProvider = Provider<TrainingPlanRepository>((ref) {
  return SupabaseConfig.enabled
      ? SupabaseTrainingPlanRepository(ref.watch(supabaseClientProvider))
      : LocalTrainingPlanRepository();
});

/// Versiones del plan de formación por seniority. Al guardar una se invalida
/// y todo el cumplimiento se recalcula.
final trainingPlanHistoryProvider = FutureProvider<TrainingPlanHistory>((ref) {
  return ref.watch(trainingPlanRepositoryProvider).getPlans();
});

final complianceServiceProvider = FutureProvider<ComplianceService>((
  ref,
) async {
  final plans = await ref.watch(trainingPlanHistoryProvider.future);
  return ComplianceService(plans: plans);
});

final importRecordsRepositoryProvider = Provider<ImportRecordsRepository?>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseImportRecordsRepository(ref.watch(supabaseClientProvider))
      : null,
);
final importAuditServiceProvider = Provider<ImportAuditService>(
  (ref) =>
      ImportAuditService(audit: ref.watch(importRecordsRepositoryProvider)),
);

final authorizedUsersRepositoryProvider = Provider<AuthorizedUsersRepository?>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseAuthorizedUsersRepository(ref.watch(supabaseClientProvider))
      : null,
);

/// Áreas, equipos y líderes. `null` en modo local: ahí no hay estructura y
/// las pantallas muestran el Sector y el Equipo tal como vienen en la nómina.
final orgStructureRepositoryProvider = Provider<OrgStructureRepository?>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseOrgStructureRepository(ref.watch(supabaseClientProvider))
      : null,
);

/// Diálogo de impresión del navegador o del sistema. Igual en los dos modos.
final printRepositoryProvider = Provider<PrintRepository>(
  (ref) => const PrintingPrintRepository(),
);
