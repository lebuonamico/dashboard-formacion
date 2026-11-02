import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:flutter_test/flutter_test.dart';

CrmTimeEntry _entry({
  String? classification,
  TimeEntryKind kind = TimeEntryKind.taken,
}) => CrmTimeEntry(
  id: '1',
  courseName: 'Curso',
  employeeId: '7',
  date: DateTime(2026, 8, 3),
  hours: 2,
  kind: kind,
  classification: classification,
);

Course _course(CourseCategory category) => Course(
  id: 'c1',
  name: 'Curso',
  category: category,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

void main() {
  final service = CourseClassificationService();

  test('el LMS valida solo Negocio y Blandas', () {
    expect(
      service.lmsCategory(_course(CourseCategory.businessSkills)),
      CourseCategory.businessSkills,
    );
    expect(
      service.lmsCategory(_course(CourseCategory.softSkills)),
      CourseCategory.softSkills,
    );
    expect(service.lmsCategory(_course(CourseCategory.exploration)), isNull);
    expect(service.lmsCategory(_course(CourseCategory.teaching)), isNull);
  });

  test('una carga es dictada por su tipo o por la Clasificación del CRM', () {
    expect(service.isTaught(_entry(kind: TimeEntryKind.taught)), isTrue);
    expect(
      service.isTaught(_entry(classification: 'Horas de Dictado')),
      isTrue,
    );
    expect(
      service.isTaught(_entry(classification: 'Habilidades Blandas')),
      isFalse,
    );
    expect(service.isTaught(_entry()), isFalse);
  });

  test('solo Libres y Dictado se acreditan por el CRM', () {
    expect(
      service.crmOnlyCategory(
        _entry(classification: 'Exploracion / Profundizacion'),
      ),
      CourseCategory.exploration,
    );
    expect(
      service.crmOnlyCategory(_entry(kind: TimeEntryKind.taught)),
      CourseCategory.teaching,
    );
    expect(
      service.crmOnlyCategory(_entry(classification: 'Habilidades de Negocio')),
      isNull,
    );
    expect(service.crmOnlyCategory(_entry()), isNull);
  });
}
