import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';

abstract class CertificacionesMoodleRepository {
  Future<List<CertificacionMoodle>> getCertificaciones();
  Future<void> replaceCertificaciones(
    List<CertificacionMoodle> certificaciones,
  );
}
