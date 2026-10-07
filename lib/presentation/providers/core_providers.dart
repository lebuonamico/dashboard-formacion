import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';
import 'package:app_finnegans/domain/servicios/importacion_service.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/data/supabase/supabase_mapping.dart';
import 'package:app_finnegans/data/supabase/supabase_importaciones_repository.dart';
import 'package:app_finnegans/data/supabase/supabase_repositories.dart';
import 'package:app_finnegans/data/supabase/supabase_usuarios_autorizados_repository.dart';
import 'package:app_finnegans/domain/repositorios/usuarios_autorizados_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/data/repositorios_separados.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
final supabaseMappingsProvider = Provider<SupabaseMappings>(
  (ref) => SupabaseMappings(
    empleados: SupabaseTableMapping(
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
    cursos: SupabaseTableMapping(
      table: 'cursos',
      conflictFields: ['id'],
      columns: {
        'id': 'id_curso',
        'nombre': 'nombre',
        'tipo': 'tipo',
        'cargaHorariaHs': 'carga_horaria',
        'activo': 'activo',
      },
    ),
    horas: SupabaseTableMapping(
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
    finalizaciones: SupabaseTableMapping(
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

final empleadosRepositoryProvider = Provider<EmpleadosRepository>((ref) {
  return SupabaseConfig.enabled
      ? SupabaseEmpleadosRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(supabaseMappingsProvider).empleados,
        )
      : LocalEmpleadosRepository();
});

final cursosRepositoryProvider = Provider<CursosRepository>((ref) {
  return SupabaseConfig.enabled
      ? SupabaseCursosRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(supabaseMappingsProvider).cursos,
        )
      : LocalCursosRepository();
});

final cargaDeHorasCRMRepositoryProvider = Provider<CargaDeHorasCRMRepository>((
  ref,
) {
  return SupabaseConfig.enabled
      ? SupabaseCargaDeHorasCRMRepository(
          ref.watch(supabaseClientProvider),
          ref.watch(supabaseMappingsProvider).horas,
          ref.watch(cursosRepositoryProvider),
        )
      : LocalCargaDeHorasCRMRepository();
});

final certificacionesMoodleRepositoryProvider =
    Provider<CertificacionesMoodleRepository>((ref) {
      return SupabaseConfig.enabled
          ? SupabaseCertificacionesMoodleRepository(
              ref.watch(supabaseClientProvider),
              ref.watch(supabaseMappingsProvider).finalizaciones,
              ref.watch(cursosRepositoryProvider),
            )
          : LocalCertificacionesMoodleRepository();
    });

final cumplimientoServiceProvider = Provider<CumplimientoService>((ref) {
  return CumplimientoService();
});

final importacionesRepositoryProvider = Provider<ImportacionesRepository?>(
  (ref) => SupabaseConfig.enabled
      ? SupabaseImportacionesRepository(ref.watch(supabaseClientProvider))
      : null,
);
final importacionServiceProvider = Provider<ImportacionService>(
  (ref) =>
      ImportacionService(auditoria: ref.watch(importacionesRepositoryProvider)),
);

final usuariosAutorizadosRepositoryProvider =
    Provider<UsuariosAutorizadosRepository?>(
      (ref) => SupabaseConfig.enabled
          ? SupabaseUsuariosAutorizadosRepository(
              ref.watch(supabaseClientProvider),
            )
          : null,
    );
