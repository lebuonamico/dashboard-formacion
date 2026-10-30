import 'package:app_finnegans/domain/importacion/valores_importacion.dart';

class LegacyTimeEntry {
  final String id;
  final String courseId;
  final String employeeId; // Alumno que tomó la clase
  final DateTime date;

  LegacyTimeEntry({
    required this.id,
    required this.courseId,
    required this.employeeId,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'cursoId': courseId,
    'empleadoLegajo': employeeId,
    'fecha': date.toIso8601String(),
  };

  factory LegacyTimeEntry.fromJson(Map<String, dynamic> json) =>
      LegacyTimeEntry(
        id: json['id']?.toString() ?? '',
        courseId: json['cursoId']?.toString() ?? '',
        employeeId: json['empleadoLegajo']?.toString() ?? '',
        date: requiredDate(json['fecha']?.toString() ?? ''),
      );
}
