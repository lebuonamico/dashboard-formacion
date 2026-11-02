import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail.dart';
import 'package:app_finnegans/features/compliance/domain/employee_detail_service.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/time_entries/domain/time_entry_records_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _teaching = 'Dictado de capacitaciones';

final _employee = Employee(
  employeeId: 'EMP-1',
  firstName: 'Ana',
  lastName: 'Pérez',
  seniority: Seniority.senior1,
  area: 'Desarrollo',
  email: 'ana@finnegans.com',
  team: 'Backend',
  hireDate: DateTime(2025, 1, 1),
);

Course _course(
  String id,
  String name, {
  CourseCategory category = CourseCategory.softSkills,
  double workloadHours = 4,
  String courseArea = '',
}) => Course(
  id: id,
  name: name,
  category: category,
  courseArea: courseArea,
  instructorEmployeeId: '',
  workloadHours: workloadHours,
);

final _courses = [
  _course('CUR-S1', 'Comunicación Asertiva', workloadHours: 6),
  _course('CUR-S2', 'Gestión del Tiempo', workloadHours: 3),
  _course(
    'CUR-T1',
    'Formación de Instructores',
    category: CourseCategory.teaching,
    courseArea: 'Academia',
  ),
];

CrmTimeEntry _entry(
  String id,
  String courseName,
  DateTime date, {
  double hours = 2,
  String employeeId = 'EMP-1',
  String? classification,
  String? courseId,
  String? courseDescription,
}) => CrmTimeEntry(
  id: id,
  courseName: courseName,
  employeeId: employeeId,
  date: date,
  hours: hours,
  kind: TimeEntryKind.taken,
  classification: classification,
  courseId: courseId,
  courseDescription: courseDescription,
);

LmsCertification _certification(
  String courseName,
  DateTime? completedAt, {
  bool isCompleted = true,
  String employeeId = 'EMP-1',
}) => LmsCertification(
  employeeId: employeeId,
  courseName: courseName,
  isCompleted: isCompleted,
  completedAt: completedAt,
);

PeriodFilter _monthly(int month) =>
    PeriodFilter(scope: PeriodScope.monthly, month: month, year: 2026);

const _annual = PeriodFilter(scope: PeriodScope.annual, month: 7, year: 2026);

final _service = EmployeeDetailService(
  records: TimeEntryRecordsService(
    classification: CourseClassificationService(),
  ),
);

EmployeeDetail _build({
  List<CrmTimeEntry> timeEntries = const [],
  List<LmsCertification> certifications = const [],
  PeriodFilter? period,
  bool hasPeriodData = true,
}) => _service.build(
  employeeId: 'EMP-1',
  employees: [_employee],
  courses: _courses,
  timeEntries: timeEntries,
  certifications: certifications,
  period: period ?? _monthly(7),
  complianceService: ComplianceService(),
  hasPeriodData: hasPeriodData,
)!;

void main() {
  test('devuelve null si el legajo no está en la nómina', () {
    final detail = _service.build(
      employeeId: 'EMP-9',
      employees: [_employee],
      courses: _courses,
      timeEntries: const [],
      certifications: const [],
      period: _monthly(7),
      complianceService: ComplianceService(),
      hasPeriodData: true,
    );

    expect(detail, isNull);
  });

  test('conserva si el período tiene datos y calcula el cumplimiento', () {
    final detail = _build(hasPeriodData: false);

    expect(detail.hasPeriodData, isFalse);
    expect(detail.employee.employeeId, 'EMP-1');
    expect(detail.compliance.employee.employeeId, 'EMP-1');
    expect(detail.compliance.requiredHours[CourseCategory.teaching], 4);
  });

  group('certificaciones', () {
    final certifications = [
      _certification('Comunicación Asertiva', DateTime(2026, 7, 5)),
      _certification(
        'Gestión del Tiempo',
        DateTime(2026, 7, 20),
        isCompleted: false,
      ),
      _certification('Curso Externo', DateTime(2026, 7, 12)),
      _certification('Gestión del Tiempo', DateTime(2026, 8, 3)),
      _certification('Comunicación Asertiva', DateTime(2025, 7, 5)),
      _certification('Formación de Instructores', null, isCompleted: false),
      _certification(
        'Comunicación Asertiva',
        DateTime(2026, 7, 6),
        employeeId: 'EMP-2',
      ),
    ];

    test('mensual: las del mes, finalizadas o no, más nuevas primero', () {
      final detail = _build(certifications: certifications);

      expect(
        detail.certifications.map(
          (item) =>
              (item.certification.courseName, item.certification.completedAt),
        ),
        [
          ('Gestión del Tiempo', DateTime(2026, 7, 20)),
          ('Curso Externo', DateTime(2026, 7, 12)),
          ('Comunicación Asertiva', DateTime(2026, 7, 5)),
        ],
      );
    });

    test('anual: todas las del año', () {
      final detail = _build(certifications: certifications, period: _annual);

      expect(
        detail.certifications.map((item) => item.certification.completedAt),
        [
          DateTime(2026, 8, 3),
          DateTime(2026, 7, 20),
          DateTime(2026, 7, 12),
          DateTime(2026, 7, 5),
        ],
      );
    });

    test('cada una trae su curso del catálogo por nombre normalizado', () {
      final detail = _build(
        certifications: [
          _certification('comunicacion asertiva', DateTime(2026, 7, 5)),
          _certification('Curso Externo', DateTime(2026, 7, 4)),
        ],
      );

      expect(detail.certifications.map((item) => item.course?.id), [
        'CUR-S1',
        null,
      ]);
    });

    test('las horas Moodle suman la carga del catálogo de las finalizadas', () {
      final detail = _build(certifications: certifications);

      // 6 h de Comunicación Asertiva; Gestión del Tiempo no finalizó y el
      // curso externo no está en el catálogo.
      expect(detail.creditedLmsHours, 6);
    });
  });

  group('cargas CRM', () {
    test('suma las horas del período', () {
      final detail = _build(
        timeEntries: [
          _entry('1', 'Comunicación Asertiva', DateTime(2026, 7, 3), hours: 2),
          _entry('2', 'Curso Externo', DateTime(2026, 7, 9), hours: 1.5),
          _entry('3', 'Comunicación Asertiva', DateTime(2026, 8, 3), hours: 5),
          _entry(
            '4',
            'Comunicación Asertiva',
            DateTime(2026, 7, 3),
            hours: 7,
            employeeId: 'EMP-2',
          ),
        ],
      );

      expect(detail.crmHours, 3.5);
      expect(
        _build(
          timeEntries: [
            _entry(
              '1',
              'Comunicación Asertiva',
              DateTime(2026, 7, 3),
              hours: 2,
            ),
            _entry(
              '3',
              'Comunicación Asertiva',
              DateTime(2026, 8, 3),
              hours: 5,
            ),
            _entry(
              '5',
              'Comunicación Asertiva',
              DateTime(2025, 8, 3),
              hours: 1,
            ),
          ],
          period: _annual,
        ).crmHours,
        7,
      );
    });

    test('agrupa por id del catálogo y ordena por nombre del curso', () {
      final detail = _build(
        timeEntries: [
          _entry('1', 'Gestión del Tiempo', DateTime(2026, 7, 3), hours: 1),
          _entry('2', 'comunicacion asertiva', DateTime(2026, 7, 4), hours: 2),
          _entry('3', 'Comunicación Asertiva', DateTime(2026, 7, 9), hours: 3),
        ],
      );

      expect(detail.timeEntryGroups.map((group) => group.key), [
        'id:CUR-S1',
        'id:CUR-S2',
      ]);
      final first = detail.timeEntryGroups.first;
      expect(first.courseName, 'Comunicación Asertiva');
      expect(first.hours, 5);
      expect(first.records.map((record) => record.timeEntry.id), ['3', '2']);
    });

    test('sin curso del catálogo agrupa por nombre con trim y minúsculas', () {
      final detail = _build(
        timeEntries: [
          _entry('1', 'Taller Docker ', DateTime(2026, 7, 3)),
          _entry('2', 'taller docker', DateTime(2026, 7, 8)),
          // normalizeKey los juntaría; esta clave no.
          _entry('3', 'Taller-Docker', DateTime(2026, 7, 5)),
        ],
      );

      expect(detail.timeEntryGroups.map((group) => group.key), [
        'nombre:taller docker',
        'nombre:taller-docker',
      ]);
      final first = detail.timeEntryGroups.first;
      // El nombre es el de la carga más nueva.
      expect(first.courseName, 'taller docker');
      expect(first.records.map((record) => record.timeEntry.id), ['2', '1']);
    });

    test('marca finalizado si lo terminó en el LMS en cualquier período', () {
      final detail = _build(
        timeEntries: [
          _entry('1', 'Comunicación Asertiva', DateTime(2026, 7, 3)),
          _entry('2', 'Gestión del Tiempo', DateTime(2026, 7, 4)),
          _entry('3', 'Formación de Instructores', DateTime(2026, 7, 5)),
        ],
        certifications: [
          _certification('comunicación asertiva', DateTime(2026, 3, 1)),
          _certification(
            'Gestión del Tiempo',
            DateTime(2026, 7, 1),
            isCompleted: false,
          ),
          _certification(
            'Formación de Instructores',
            DateTime(2026, 7, 1),
            employeeId: 'EMP-2',
          ),
        ],
      );

      expect(
        {
          for (final group in detail.timeEntryGroups)
            group.courseName: group.isCompleted,
        },
        {
          'Comunicación Asertiva': true,
          'Formación de Instructores': false,
          'Gestión del Tiempo': false,
        },
      );
    });
  });

  group('cursos dictados', () {
    test('agrupa por id del catálogo o del CRM y por nombre sin tildes ni '
        'símbolos', () {
      final detail = _build(
        timeEntries: [
          _entry(
            '1',
            'Formación de Instructores',
            DateTime(2026, 7, 3),
            classification: _teaching,
          ),
          _entry(
            '2',
            'formacion de instructores',
            DateTime(2026, 7, 10),
            hours: 3,
            classification: _teaching,
          ),
          _entry(
            '3',
            'Charla Interna',
            DateTime(2026, 7, 4),
            classification: _teaching,
            courseId: 'CRM-9',
            courseDescription: 'Comunidad',
          ),
          _entry(
            '4',
            'Charla Interna (v2)',
            DateTime(2026, 7, 6),
            hours: 1,
            classification: _teaching,
            courseId: 'CRM-9',
          ),
          _entry(
            '5',
            'Taller Git',
            DateTime(2026, 7, 7),
            hours: 1,
            classification: _teaching,
          ),
          _entry(
            '6',
            'taller-git!',
            DateTime(2026, 7, 8),
            hours: 1.5,
            classification: _teaching,
          ),
          // No es dictado.
          _entry('7', 'Comunicación Asertiva', DateTime(2026, 7, 9)),
          // Fuera del período.
          _entry(
            '8',
            'Formación de Instructores',
            DateTime(2026, 8, 3),
            classification: _teaching,
          ),
        ],
      );

      expect(
        detail.taughtCourses.map(
          (course) => (course.code, course.name, course.area, course.hours),
        ),
        [
          ('CRM-9', 'Charla Interna', 'Comunidad', 3),
          ('CUR-T1', 'Formación de Instructores', 'Academia', 5),
          ('', 'Taller Git', '', 2.5),
        ],
      );
    });

    test('una carga de tipo dictada también cuenta', () {
      final detail = _build(
        timeEntries: [
          CrmTimeEntry(
            id: '1',
            courseName: 'Formación de Instructores',
            employeeId: 'EMP-1',
            date: DateTime(2026, 7, 3),
            hours: 2,
            kind: TimeEntryKind.taught,
          ),
        ],
      );

      expect(detail.taughtCourses.single.code, 'CUR-T1');
    });
  });
}
