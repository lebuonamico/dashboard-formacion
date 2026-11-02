import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';

LmsCertification _completed(
  String employeeId,
  String courseName,
  DateTime at,
) => LmsCertification(
  employeeId: employeeId,
  courseName: courseName,
  isCompleted: true,
  completedAt: at,
);

final lmsCertificationsSeed = [
  _completed(
    'EMP-001',
    'Estrategia y Modelos de Negocio',
    DateTime(2026, 7, 10),
  ),
  _completed(
    'EMP-001',
    'Comunicación Asertiva y Feedback',
    DateTime(2026, 7, 17),
  ),
  _completed('EMP-001', 'Finanzas Básicas para Tech', DateTime(2026, 8, 11)),
  _completed(
    'EMP-001',
    'Gestión del Tiempo y Priorización',
    DateTime(2026, 8, 18),
  ),
  _completed('EMP-001', 'Negociación con Clientes', DateTime(2026, 9, 8)),
  _completed('EMP-001', 'Trabajo en Equipo Remoto', DateTime(2026, 9, 15)),
  _completed(
    'EMP-002',
    'Estrategia y Modelos de Negocio',
    DateTime(2026, 7, 11),
  ),
  _completed(
    'EMP-002',
    'Comunicación Asertiva y Feedback',
    DateTime(2026, 7, 18),
  ),
  _completed('EMP-002', 'Finanzas Básicas para Tech', DateTime(2026, 8, 12)),
  _completed(
    'EMP-002',
    'Gestión del Tiempo y Priorización',
    DateTime(2026, 8, 19),
  ),
  _completed('EMP-002', 'Negociación con Clientes', DateTime(2026, 9, 9)),
  _completed('EMP-002', 'Trabajo en Equipo Remoto', DateTime(2026, 9, 16)),
  _completed(
    'EMP-005',
    'Comunicación Asertiva y Feedback',
    DateTime(2026, 7, 12),
  ),
  _completed(
    'EMP-005',
    'Gestión del Tiempo y Priorización',
    DateTime(2026, 8, 13),
  ),
  _completed('EMP-005', 'Trabajo en Equipo Remoto', DateTime(2026, 9, 10)),
  _completed(
    'EMP-006',
    'Comunicación Asertiva y Feedback',
    DateTime(2026, 7, 14),
  ),
  _completed(
    'EMP-006',
    'Gestión del Tiempo y Priorización',
    DateTime(2026, 8, 14),
  ),
  _completed('EMP-006', 'Trabajo en Equipo Remoto', DateTime(2026, 9, 11)),
  const LmsCertification(
    employeeId: 'EMP-008',
    courseName: 'Estrategia y Modelos de Negocio',
    isCompleted: false,
  ),
];
