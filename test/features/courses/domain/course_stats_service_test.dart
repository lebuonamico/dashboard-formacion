import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/courses/domain/course_stats_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:flutter_test/flutter_test.dart';

Course _course(
  String id,
  String name,
  CourseCategory category, {
  String instructor = '',
}) => Course(
  id: id,
  name: name,
  category: category,
  courseArea: '',
  instructorEmployeeId: instructor,
  workloadHours: 4,
);

Employee _employee(String id, String firstName, String lastName) => Employee(
  employeeId: id,
  firstName: firstName,
  lastName: lastName,
  seniority: Seniority.junior1,
  area: 'Servicios',
  email: '$id@finnegans.com',
);

var _nextId = 0;

CrmTimeEntry _entry(
  String course,
  String employeeId,
  DateTime date,
  double hours, {
  TimeEntryKind kind = TimeEntryKind.taken,
}) => CrmTimeEntry(
  id: '${_nextId++}',
  courseName: course,
  employeeId: employeeId,
  date: date,
  hours: hours,
  kind: kind,
);

LmsCertification _certification(
  String course,
  String employeeId, {
  bool isCompleted = true,
  DateTime? completedAt,
}) => LmsCertification(
  employeeId: employeeId,
  courseName: course,
  isCompleted: isCompleted,
  completedAt: completedAt,
);

void main() {
  final service = CourseStatsService(
    classification: CourseClassificationService(),
  );
  final july = DateTime(2026, 7, 10);
  final june = DateTime(2026, 6, 10);

  final stats = service.calculate(
    courses: [
      _course('C1', 'Oratoria', CourseCategory.softSkills, instructor: '10'),
      _course(
        'C2',
        'Dictado de Git',
        CourseCategory.teaching,
        instructor: '99',
      ),
      _course('C3', 'Excel', CourseCategory.businessSkills),
    ],
    employees: [
      _employee('10', 'Ana', 'Pérez'),
      _employee('20', 'Juan', 'Gómez'),
    ],
    timeEntries: [
      _entry('Oratoria', '20', july, 2),
      _entry(' ORATORIA ', '20', july, 1),
      _entry('Oratoria', '30', july, 3),
      // Fuera del período: no suma.
      _entry('Oratoria', '20', june, 5),
      _entry('Dictado de Git', '10', july, 2, kind: TimeEntryKind.taught),
    ],
    certifications: [
      _certification('Oratoria', '20', completedAt: july),
      _certification('oratoria', '20', completedAt: july),
      _certification('Oratoria', '30', completedAt: june),
      _certification('Oratoria', '40', isCompleted: false, completedAt: july),
      _certification('Oratoria', '50'),
    ],
    inPeriod: (date) => date.year == 2026 && date.month == 7,
  );

  test('Devuelve un resultado por curso del catálogo, en su orden', () {
    expect(stats.map((item) => item.course.id), ['C1', 'C2', 'C3']);
  });

  test('Suma las horas CRM del período y cuenta personas distintas', () {
    final oratoria = stats[0];

    expect(oratoria.crmHours, 6);
    expect(oratoria.people, 2);
    expect(oratoria.averageHoursPerPerson, 3);
  });

  test('Cuenta finalizaciones del período, una por persona', () {
    expect(stats[0].completed, 1);
  });

  test('El instructor se muestra por nombre, o por legajo si no está', () {
    expect(stats[0].instructorName, 'Ana Pérez');
    expect(stats[1].instructorName, '99');
  });

  test('Solo Negocio y Blandas tienen categoría del LMS', () {
    expect(stats[0].lmsCategory, CourseCategory.softSkills);
    expect(stats[1].lmsCategory, isNull);
    expect(stats[2].lmsCategory, CourseCategory.businessSkills);
  });

  test('Las horas de dictado cuentan como actividad del curso', () {
    expect(stats[1].people, 1);
    expect(stats[1].crmHours, 2);
  });

  test('Un curso sin actividad no tiene promedio', () {
    final excel = stats[2];

    expect(excel.people, 0);
    expect(excel.crmHours, 0);
    expect(excel.averageHoursPerPerson, isNull);
    expect(excel.completed, 0);
  });
}
