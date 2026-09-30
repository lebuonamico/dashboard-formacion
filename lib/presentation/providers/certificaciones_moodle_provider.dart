import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:flutter_riverpod/legacy.dart';

final certificacionesMoodleProvider = FutureProvider<List<CertificacionMoodle>>(
  (ref) {
    return ref
        .watch(certificacionesMoodleRepositoryProvider)
        .getCertificaciones();
  },
);

final busquedaCertificacionMoodleProvider = StateProvider<String>((ref) => '');
