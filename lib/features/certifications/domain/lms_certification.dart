import 'package:app_finnegans/features/imports/domain/import_values.dart';

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
    'courseId': courseId,
    'employeeId': employeeId,
    'courseName': courseName,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory LmsCertification.fromJson(Map<String, dynamic> json) {
    final completed = json['isCompleted'];
    return LmsCertification(
      courseId: json['courseId']?.toString(),
      employeeId: json['employeeId']?.toString() ?? '',
      courseName: json['courseName']?.toString() ?? '',
      isCompleted: completed == true || completed?.toString() == 'true',
      completedAt: json['completedAt'] == null
          ? null
          : requiredDate(json['completedAt'].toString()),
    );
  }
}
