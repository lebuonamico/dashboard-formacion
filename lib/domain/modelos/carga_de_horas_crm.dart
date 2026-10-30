import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

enum TimeEntryKind { taken, taught }

class CrmTimeEntry {
  final String? courseId;
  final String? caseRef;
  final String? courseDescription;
  final String? classification;
  final String? project;
  final String? projectItem;
  final String? description;
  final String id;
  final String courseName;
  final String employeeId;
  final DateTime date;
  final double hours;
  final TimeEntryKind kind;

  const CrmTimeEntry({
    this.courseId,
    this.caseRef,
    this.courseDescription,
    this.classification,
    this.project,
    this.projectItem,
    this.description,
    required this.id,
    required this.courseName,
    required this.employeeId,
    required this.date,
    required this.hours,
    required this.kind,
  });

  /// Categoría indicada en la columna Clasificación del CRM, si se reconoce.
  CourseCategory? get classificationCategory =>
      CourseCategory.fromText(classification);

  bool get isTaught =>
      kind == TimeEntryKind.taught ||
      classificationCategory == CourseCategory.teaching;

  /// Libres y Dictado nunca llegan por el LMS: se acreditan solo con el CRM.
  CourseCategory? get categoryOnlyCrm {
    if (isTaught) return CourseCategory.teaching;
    if (classificationCategory == CourseCategory.exploration) {
      return CourseCategory.exploration;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'cursoId': courseId,
    'caso': caseRef,
    'descripcionCurso': courseDescription,
    'clasificacion': classification,
    'proyecto': project,
    'proyectoItem': projectItem,
    'descripcion': description,
    'id': id,
    'cursoNombre': courseName,
    'empleadoLegajo': employeeId,
    'fecha': date.toIso8601String(),
    'horasTotales': hours,
    'tipo': kind.name,
  };

  factory CrmTimeEntry.fromJson(Map<String, dynamic> json) => CrmTimeEntry(
    courseId: json['cursoId']?.toString(),
    caseRef: json['caso']?.toString(),
    courseDescription: json['descripcionCurso']?.toString(),
    classification: json['clasificacion']?.toString(),
    project: json['proyecto']?.toString(),
    projectItem: json['proyectoItem']?.toString(),
    description: json['descripcion']?.toString(),
    id: json['id']?.toString() ?? '',
    courseName: json['cursoNombre']?.toString() ?? '',
    employeeId: json['empleadoLegajo']?.toString() ?? '',
    date: requiredDate(json['fecha']?.toString() ?? ''),
    hours: double.tryParse(json['horasTotales']?.toString() ?? '') ?? 0,
    kind: json['tipo']?.toString() == TimeEntryKind.taught.name
        ? TimeEntryKind.taught
        : TimeEntryKind.taken,
  );
}
