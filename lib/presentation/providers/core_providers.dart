import 'package:app_finnegans/domain/repositorios/importaciones_repository.dart';
import 'package:app_finnegans/domain/servicios/importacion_service.dart';
import 'package:app_finnegans/core/config/supabase_config.dart';
import 'package:app_finnegans/data/supabase/supabase_mapping.dart';
import 'package:app_finnegans/data/supabase/supabase_repositories.dart';
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
// Override after the physical schema and conflict constraints have been agreed.
final supabaseMappingsProvider = Provider<SupabaseMappings>(
  (ref) => throw StateError('Falta configurar el mapeo del esquema Supabase.'),
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

// No-op audit storage until the physical audit schema is designed.
final importacionesRepositoryProvider = Provider<ImportacionesRepository?>(
  (ref) => null,
);
final importacionServiceProvider = Provider<ImportacionService>(
  (ref) =>
      ImportacionService(auditoria: ref.watch(importacionesRepositoryProvider)),
);
