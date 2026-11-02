import 'package:app_finnegans/features/courses/domain/course_category.dart';

class Course {
  final String id;
  final String name;
  final CourseCategory category;
  final String courseArea;
  final String instructorEmployeeId;
  final double workloadHours;
  final bool isActive;

  Course({
    required this.id,
    required this.name,
    required this.category,
    required this.courseArea,
    required this.instructorEmployeeId,
    required this.workloadHours,
    this.isActive = true,
  });

  Course copyWith({
    String? id,
    String? name,
    CourseCategory? category,
    String? courseArea,
    String? instructorEmployeeId,
    double? workloadHours,
    bool? isActive,
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    courseArea: courseArea ?? this.courseArea,
    instructorEmployeeId: instructorEmployeeId ?? this.instructorEmployeeId,
    workloadHours: workloadHours ?? this.workloadHours,
    isActive: isActive ?? this.isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'courseArea': courseArea,
    'instructorEmployeeId': instructorEmployeeId,
    'workloadHours': workloadHours,
    'isActive': isActive,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    category: CourseCategory.values.firstWhere(
      (type) => type.name == json['category'],
      orElse: () => CourseCategory.exploration,
    ),
    courseArea: json['courseArea']?.toString() ?? '',
    instructorEmployeeId: json['instructorEmployeeId']?.toString() ?? '',
    workloadHours: double.tryParse(json['workloadHours'].toString()) ?? 0,
    isActive: json['isActive'] as bool? ?? true,
  );
}
