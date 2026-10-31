import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

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
    'courseId': courseId,
    'caseRef': caseRef,
    'courseDescription': courseDescription,
    'classification': classification,
    'project': project,
    'projectItem': projectItem,
    'description': description,
    'id': id,
    'courseName': courseName,
    'employeeId': employeeId,
    'date': date.toIso8601String(),
    'hours': hours,
    'kind': kind.name,
  };

  factory CrmTimeEntry.fromJson(Map<String, dynamic> json) => CrmTimeEntry(
    courseId: json['courseId']?.toString(),
    caseRef: json['caseRef']?.toString(),
    courseDescription: json['courseDescription']?.toString(),
    classification: json['classification']?.toString(),
    project: json['project']?.toString(),
    projectItem: json['projectItem']?.toString(),
    description: json['description']?.toString(),
    id: json['id']?.toString() ?? '',
    courseName: json['courseName']?.toString() ?? '',
    employeeId: json['employeeId']?.toString() ?? '',
    date: requiredDate(json['date']?.toString() ?? ''),
    hours: double.tryParse(json['hours']?.toString() ?? '') ?? 0,
    kind: json['kind']?.toString() == TimeEntryKind.taught.name
        ? TimeEntryKind.taught
        : TimeEntryKind.taken,
  );
}
