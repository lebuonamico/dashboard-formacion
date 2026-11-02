import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

Course _course(
  String id,
  String name,
  CourseCategory category,
  double workloadHours,
) => Course(
  id: id,
  name: name,
  category: category,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: workloadHours,
);

final coursesSeed = [
  _course(
    'CUR-B1',
    'Estrategia y Modelos de Negocio',
    CourseCategory.businessSkills,
    4,
  ),
  _course(
    'CUR-B2',
    'Finanzas Básicas para Tech',
    CourseCategory.businessSkills,
    4,
  ),
  _course(
    'CUR-B3',
    'Negociación con Clientes',
    CourseCategory.businessSkills,
    4,
  ),
  _course(
    'CUR-S1',
    'Comunicación Asertiva y Feedback',
    CourseCategory.softSkills,
    4,
  ),
  _course(
    'CUR-S2',
    'Gestión del Tiempo y Priorización',
    CourseCategory.softSkills,
    4,
  ),
  _course('CUR-S3', 'Trabajo en Equipo Remoto', CourseCategory.softSkills, 4),
  _course(
    'CUR-E1',
    'Exploración de Arquitecturas Serverless',
    CourseCategory.exploration,
    2,
  ),
  _course('CUR-T1', 'Formación de Instructores', CourseCategory.teaching, 4),
];
