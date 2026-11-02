import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

const _business = 'Habilidades de negocio';
const _soft = 'Habilidades blandas';
const _exploration = 'Libres / exploración';
const _teaching = 'Dictado de capacitaciones';
const _explorationCourse = 'Exploración de Arquitecturas Serverless';
const _teachingCourse = 'Formación de Instructores';

/// One business and one soft skills course per month: a completion is unique
/// per employee and course, so each month needs a different one.
const _monthCourses = {
  7: (
    business: 'Estrategia y Modelos de Negocio',
    soft: 'Comunicación Asertiva y Feedback',
  ),
  8: (
    business: 'Finanzas Básicas para Tech',
    soft: 'Gestión del Tiempo y Priorización',
  ),
  9: (business: 'Negociación con Clientes', soft: 'Trabajo en Equipo Remoto'),
};

const _year = 2026;

List<CrmTimeEntry> _monthEntries(
  int month,
  ({String business, String soft}) courses,
) {
  CrmTimeEntry entry(
    int index,
    String employeeId,
    String courseName,
    String classification,
    double hours,
    int day,
  ) => CrmTimeEntry(
    id: 'CRM-$_year${month.toString().padLeft(2, '0')}-$index',
    employeeId: employeeId,
    courseName: courseName,
    classification: classification,
    project: '01 - Capacitación',
    date: DateTime(_year, month, day),
    hours: hours,
    kind: TimeEntryKind.taken,
  );

  return [
    entry(1, 'EMP-001', courses.business, _business, 4, 6),
    entry(2, 'EMP-001', courses.soft, _soft, 4, 13),
    entry(3, 'EMP-002', courses.business, _business, 4, 7),
    entry(4, 'EMP-002', courses.soft, _soft, 4, 14),
    entry(5, 'EMP-003', _explorationCourse, _exploration, 8, 20),
    entry(6, 'EMP-005', courses.soft, _soft, 4, 8),
    entry(7, 'EMP-005', _explorationCourse, _exploration, 2, 15),
    entry(8, 'EMP-005', _teachingCourse, _teaching, 4, 22),
    entry(9, 'EMP-006', courses.soft, _soft, 4, 9),
    entry(10, 'EMP-007', _explorationCourse, _exploration, 1, 16),
    entry(11, 'EMP-008', 'Estrategia y Modelos de Negocio', _business, 2, 10),
  ];
}

final crmTimeEntriesSeed = [
  for (final month in _monthCourses.entries)
    ..._monthEntries(month.key, month.value),
];
