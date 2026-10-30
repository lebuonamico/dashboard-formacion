import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

class Course {
  final String id;
  final String name;
  final CourseCategory category;
  final String courseArea;
  final String instructorEmployeeId; // Empleado que dicta
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

  // La clasificación histórica se conserva para CRM y cumplimiento.
  CourseCategory? get classificationLms => switch (category) {
    CourseCategory.businessSkills || CourseCategory.softSkills => category,
    _ => null,
  };

  Course copyWith({String? id, bool? active}) => Course(
    id: id ?? this.id,
    name: name,
    category: category,
    courseArea: courseArea,
    instructorEmployeeId: instructorEmployeeId,
    workloadHours: workloadHours,
    isActive: active ?? isActive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': name,
    'clasificacion': category.name,
    'areaCurso': courseArea,
    'instructorLegajo': instructorEmployeeId,
    'cargaHorariaHs': workloadHours,
    'activo': isActive,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json['id']?.toString() ?? '',
    name: json['nombre']?.toString() ?? '',
    category: CourseCategory.values.firstWhere(
      (type) => type.name == json['clasificacion'],
      orElse: () => CourseCategory.exploration,
    ),
    courseArea: json['areaCurso']?.toString() ?? '',
    instructorEmployeeId: json['instructorLegajo']?.toString() ?? '',
    workloadHours: double.tryParse(json['cargaHorariaHs'].toString()) ?? 0,
    isActive: json['activo'] as bool? ?? true,
  );
}
