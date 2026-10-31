import 'package:app_finnegans/features/certifications/domain/certification_stats_service.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter_test/flutter_test.dart';

LmsCertification _cert(
  String employeeId,
  String course, {
  DateTime? at,
  bool done = true,
}) => LmsCertification(
  employeeId: employeeId,
  courseName: course,
  isCompleted: done,
  completedAt: at,
);

void main() {
  final service = CertificationStatsService(
    classification: CourseClassificationService(),
  );
  final employees = [
    Employee(
      employeeId: '1',
      firstName: 'Ana',
      lastName: 'Ruiz',
      seniority: Seniority.junior1,
      area: 'Core',
      email: 'ana@x.com',
    ),
  ];
  final courses = [
    Course(
      id: 'c1',
      name: 'Gestión Ágil',
      category: CourseCategory.businessSkills,
      courseArea: '',
      instructorEmployeeId: '',
      workloadHours: 4,
    ),
    Course(
      id: 'c2',
      name: 'Exploración',
      category: CourseCategory.exploration,
      courseArea: '',
      instructorEmployeeId: '',
      workloadHours: 2,
    ),
  ];

  final records = service.join(
    certifications: [
      _cert('1', 'Pendiente', done: false),
      _cert('1', 'gestion agil', at: DateTime(2026, 7, 1)),
      _cert('9', 'Exploración', at: DateTime(2026, 8, 1)),
      _cert('1', 'Exploracion', at: DateTime(2026, 8, 1)),
    ],
    employees: employees,
    courses: courses,
  );

  test(
    'ordena por fecha descendente, a igual fecha por nombre, y sin fecha al final',
    () {
      expect(
        records.map(
          (r) => (r.certification.employeeId, r.certification.courseName),
        ),
        [
          ('1', 'Exploracion'),
          ('9', 'Exploración'),
          ('1', 'gestion agil'),
          ('1', 'Pendiente'),
        ],
      );
    },
  );

  test('cruza con el normalizador del cálculo y marca lo que queda afuera', () {
    final agil = records[2];
    expect(agil.course?.id, 'c1');
    expect(agil.lmsCategory, CourseCategory.businessSkills);
    expect(agil.outsideCalculation, isFalse);

    expect(records[0].lmsCategory, isNull);
    expect(records[1].employeeIdOutsidePayroll, isTrue);
    expect(records[1].outsideCalculation, isTrue);
    expect(records[3].courseOutsideCatalog, isTrue);
  });

  test('los KPIs resumen todo lo importado', () {
    final kpis = service.kpis(records);
    expect(kpis.total, 4);
    expect(kpis.completed, 3);
    expect(kpis.pending, 1);
    expect(kpis.outsideCalculation, 2);
    expect(kpis.certifiedEmployees, 1);
    expect(kpis.completedPercentage, 75);
    expect(service.kpis([]).completedPercentage, 0);
  });
}
