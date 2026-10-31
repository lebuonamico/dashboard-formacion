import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/domain/time_entry_records_service.dart';
import 'package:flutter_test/flutter_test.dart';

CrmTimeEntry _entry(String id, DateTime date, String course, {String? type}) =>
    CrmTimeEntry(
      id: id,
      courseName: course,
      employeeId: '7',
      date: date,
      hours: 2,
      kind: TimeEntryKind.taken,
      classification: type,
    );

void main() {
  final service = TimeEntryRecordsService(
    classification: CourseClassificationService(),
  );
  final ana = Employee(
    employeeId: '7',
    firstName: 'Ana',
    lastName: 'Ruiz',
    seniority: Seniority.junior1,
    area: 'Core',
    email: 'ana@x.com',
  );
  final scrum = Course(
    id: 'c1',
    name: 'Scrum Básico',
    category: CourseCategory.softSkills,
    courseArea: '',
    instructorEmployeeId: '',
    workloadHours: 4,
  );

  test('cruza con nómina y catálogo, filtra el período y ordena', () {
    final records = service.join(
      timeEntries: [
        _entry('1', DateTime(2026, 8, 2), ' scrum básico '),
        _entry('2', DateTime(2026, 8, 20), 'Otro', type: 'Horas de Dictado'),
        _entry('3', DateTime(2026, 9, 1), 'Scrum Básico'),
      ],
      employees: [ana],
      courses: [scrum],
      inPeriod: (date) => date.month == 8,
    );

    expect(records.map((r) => r.timeEntry.id), ['2', '1']);
    expect(records.first.course, isNull);
    expect(records.first.isTaught, isTrue);
    expect(records.last.course, same(scrum));
    expect(records.last.employee, same(ana));
    expect(records.last.isTaught, isFalse);
  });

  test('una carga de alguien fuera de la nómina queda sin empleado', () {
    final records = service.join(
      timeEntries: [
        _entry(
          '1',
          DateTime(2026, 8, 2),
          'Scrum Básico',
        ).copyWith(employeeId: '99'),
      ],
      employees: [ana],
      courses: [scrum],
      inPeriod: (_) => true,
    );
    expect(records.single.employee, isNull);
  });
}
