import 'package:app_finnegans/domain/importacion/valores_importacion.dart';

class CertificacionMoodle {
  final String? cursoId;
  final String legajo;
  final String cursoNombre;
  final bool finalizoCurso;
  final DateTime? fechaFinalizacion;

  const CertificacionMoodle({
    this.cursoId,
    required this.legajo,
    required this.cursoNombre,
    required this.finalizoCurso,
    this.fechaFinalizacion,
  });

  Map<String, dynamic> toJson() => {
    'cursoId': cursoId,
    'legajo': legajo,
    'cursoNombre': cursoNombre,
    'finalizoCurso': finalizoCurso,
    'fechaFinalizacion': fechaFinalizacion?.toIso8601String(),
  };

  factory CertificacionMoodle.fromJson(Map<String, dynamic> json) {
    final finalizo = json['finalizoCurso'];
    return CertificacionMoodle(
      cursoId: json['cursoId']?.toString(),
      legajo: json['legajo']?.toString() ?? '',
      cursoNombre: json['cursoNombre']?.toString() ?? '',
      finalizoCurso: finalizo == true || finalizo?.toString() == 'true',
      fechaFinalizacion: json['fechaFinalizacion'] == null
          ? null
          : fechaObligatoria(json['fechaFinalizacion'].toString()),
    );
  }
}
