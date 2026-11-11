import 'package:app_finnegans/features/certifications/domain/certification_record.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

Employee _employee(
  String id,
  String firstName, {
  String email = 'x@finnegans.com',
  bool active = true,
}) => Employee(
  employeeId: id,
  firstName: firstName,
  lastName: 'Test',
  seniority: Seniority.junior1,
  area: 'Software',
  team: 'Integraciones',
  email: email,
  isActive: active,
);

Course _course(String id, String name) => Course(
  id: id,
  name: name,
  category: CourseCategory.businessSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

CertificationRecord _record(
  String employeeId,
  Course course, {
  Employee? employee,
  bool done = false,
}) => CertificationRecord(
  certification: LmsCertification(
    employeeId: employeeId,
    courseName: course.name,
    isCompleted: done,
    completedAt: done ? DateTime(2026, 9, 1) : null,
  ),
  employee: employee,
  course: course,
  lmsCategory: CourseCategory.businessSkills,
  courseOutsideCatalog: false,
  employeeIdOutsidePayroll: employee == null,
  outsideCalculation: employee == null,
);

void main() {
  const service = PendingReminderService();
  final ana = _employee('1', 'Ana', email: ' ana@finnegans.com ');
  final beto = _employee('2', 'Beto');
  final accesos = _course('C1', 'Administración de accesos');
  final oratoria = _course('C2', 'Oratoria');
  final agil = _course('C3', 'Gestión ágil');

  test('Agrupa por persona, sin cursos repetidos y ordenados por nombre', () {
    final plan = service.plan([
      _record('1', oratoria, employee: ana),
      _record('1', accesos, employee: ana),
      _record('1', accesos, employee: ana),
      _record('2', agil, employee: beto),
    ]);

    expect(plan.reminders.map((r) => r.fullName), ['Ana Test', 'Beto Test']);
    final first = plan.reminders.first;
    expect(first.email, 'ana@finnegans.com');
    expect(first.courses.map((c) => c.courseId), ['C1', 'C2']);
    expect(plan.courseCount, 3);
    expect(plan.skipped, isEmpty);
  });

  test('Los cursos finalizados no se notifican', () {
    final plan = service.plan([
      _record('1', accesos, employee: ana, done: true),
      _record('1', oratoria, employee: ana),
      _record('2', agil, employee: beto, done: true),
    ]);

    expect(plan.reminders, hasLength(1));
    expect(plan.reminders.single.courses.map((c) => c.courseName), [
      'Oratoria',
    ]);
  });

  test('Con un curso filtrado, cada persona recibe solo ese curso', () {
    // La pantalla ya filtró por curso: solo llegan los registros de accesos.
    final plan = service.plan([
      _record('1', accesos, employee: ana),
      _record('2', accesos, employee: beto),
    ]);

    expect(
      plan.reminders.every(
        (r) => r.courses.length == 1 && r.courses.single.courseId == 'C1',
      ),
      isTrue,
    );
  });

  test('Omite a quien no tiene mail, está inactivo o fuera de la nómina', () {
    final plan = service.plan([
      _record('3', accesos, employee: _employee('3', 'Caro', email: ' ')),
      _record('4', accesos, employee: _employee('4', 'Dani', active: false)),
      _record('99', accesos),
      _record('99', oratoria),
      _record('1', accesos, employee: ana),
    ]);

    expect(plan.reminders.map((r) => r.employeeId), ['1']);
    final reasons = {
      for (final skipped in plan.skipped) skipped.employeeId: skipped.reason,
    };
    expect(reasons, {
      '3': SkipReason.missingEmail,
      '4': SkipReason.inactive,
      '99': SkipReason.outsidePayroll,
    });
    final outside = plan.skipped.firstWhere((s) => s.employeeId == '99');
    expect(outside.fullName, isEmpty);
    expect(outside.pendingCourses, 2);
  });

  test('Sin pendientes el plan queda vacío', () {
    final plan = service.plan([
      _record('1', accesos, employee: ana, done: true),
    ]);

    expect(plan.reminders, isEmpty);
    expect(plan.skipped, isEmpty);
    expect(service.plan(const []).reminders, isEmpty);
  });
}
