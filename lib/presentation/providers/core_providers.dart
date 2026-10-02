import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/data/repositorios_supabase.dart';
import 'package:app_finnegans/domain/repositorios/carga_de_horas_crm_repository.dart';
import 'package:app_finnegans/domain/repositorios/certificaciones_moodle_repository.dart';
import 'package:app_finnegans/domain/repositorios/cursos_repository.dart';
import 'package:app_finnegans/domain/repositorios/empleados_repository.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

final empleadosRepositoryProvider = Provider<EmpleadosRepository>((ref) {
  return SupabaseEmpleadosRepository();
});

final cursosRepositoryProvider = Provider<CursosRepository>((ref) {
  return SupabaseCursosRepository();
});

final cargaDeHorasCRMRepositoryProvider = Provider<CargaDeHorasCRMRepository>((
  ref,
) {
  return SupabaseCargaDeHorasCRMRepository();
});

final certificacionesMoodleRepositoryProvider =
    Provider<CertificacionesMoodleRepository>((ref) {
      return SupabaseCertificacionesMoodleRepository();
    });

final cumplimientoServiceProvider = Provider<CumplimientoService>((ref) {
  return CumplimientoService();
});
