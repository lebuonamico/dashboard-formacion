import 'package:app_finnegans/domain/repositorios/formacion_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/data/formacion_repository.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

final formacionRepositoryProvider = Provider<FormacionRepository>((ref) {
  return MockFormacionRepository();
});

final cumplimientoServiceProvider = Provider<CumplimientoService>((ref) {
  return CumplimientoService();
});