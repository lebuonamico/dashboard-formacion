import 'package:app_finnegans/domain/importacion/valores_importacion.dart';

class LmsCertification {
  final String? courseId;
  final String employeeId;
  final String courseName;
  final bool isCompleted;
  final DateTime? completedAt;

  const LmsCertification({
    this.courseId,
    required this.employeeId,
    required this.courseName,
    required this.isCompleted,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'cursoId': courseId,
    'legajo': employeeId,
    'cursoNombre': courseName,
    'finalizoCurso': isCompleted,
    'fechaFinalizacion': completedAt?.toIso8601String(),
  };

  factory LmsCertification.fromJson(Map<String, dynamic> json) {
    final completed = json['finalizoCurso'];
    return LmsCertification(
      courseId: json['cursoId']?.toString(),
      employeeId: json['legajo']?.toString() ?? '',
      courseName: json['cursoNombre']?.toString() ?? '',
      isCompleted: completed == true || completed?.toString() == 'true',
      completedAt: json['fechaFinalizacion'] == null
          ? null
          : requiredDate(json['fechaFinalizacion'].toString()),
    );
  }
}
