import 'dart:io';

import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/reports/presentation/pdf/report_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_defaults.dart';

EmployeeCompliance _member(
  int employeeId,
  String name,
  String team,
  Seniority seniority,
  List<double> valid,
  List<double> declared,
) {
  final required = {
    CourseCategory.businessSkills:
        TrainingPlanDefaults.hours[seniority]![CourseCategory.businessSkills]!,
    CourseCategory.softSkills:
        TrainingPlanDefaults.hours[seniority]![CourseCategory.softSkills]!,
    CourseCategory.exploration:
        TrainingPlanDefaults.hours[seniority]![CourseCategory.exploration]!,
    CourseCategory.teaching:
        TrainingPlanDefaults.hours[seniority]![CourseCategory.teaching]!,
  };
  final parts = name.split(' ');
  return EmployeeCompliance(
    employee: Employee(
      employeeId: '$employeeId',
      firstName: parts.first,
      lastName: parts.last,
      seniority: seniority,
      area: 'Desarrollo',
      email: '$employeeId@example.com',
      team: team,
    ),
    creditedHours: {
      for (final (i, type) in CourseCategory.values.indexed) type: valid[i],
    },
    declaredHours: {
      for (final (i, type) in CourseCategory.values.indexed) type: declared[i],
    },
    requiredHours: required,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final members = [
    _member(
      101,
      'Ana Pérez',
      'Core',
      Seniority.junior2,
      [6, 4, 0, 0],
      [3, 4, 0, 0],
    ),
    _member(
      102,
      'Bruno Gómez',
      'Core',
      Seniority.semisenior2,
      [2, 1, 0, 0],
      [2, 1, 0, 0],
    ),
    _member(
      103,
      'Carla Núñez',
      'Mobile',
      Seniority.senior1,
      [0, 2, 2, 4],
      [0, 2, 2, 4],
    ),
    _member(
      104,
      'Diego Ruiz',
      'Mobile',
      Seniority.trainee,
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ),
  ];

  TrainingReport report({ReportType type = ReportType.area}) => TrainingReport(
    type: type,
    title: 'Desarrollo',
    details: const ['Líder: María López', '2 equipos'],
    period: 'Octubre 2026',
    memberCount: 4,
    onTarget: 2,
    hours: 21,
    target: 34,
    percentage: 61.8,
    status: 'Crítico',
    level: ReportLevel.critical,
    members: members,
    breakdown: const [
      ReportBreakdownRow(
        name: 'Core',
        memberCount: 2,
        hours: 11,
        target: 16,
        percentage: 68.8,
        status: 'Crítico',
        level: ReportLevel.critical,
      ),
      ReportBreakdownRow(
        name: 'Mobile',
        memberCount: 2,
        hours: 10,
        target: 18,
        percentage: 55.6,
        status: 'En riesgo',
        level: ReportLevel.attention,
      ),
    ],
    evolution: [
      (month: DateTime(2026, 7), hours: 3.2),
      (month: DateTime(2026, 8), hours: 4.1),
      (month: DateTime(2026, 9), hours: 2.7),
      (month: DateTime(2026, 10), hours: 5.3),
    ],
  );

  test('genera el PDF del reporte con tildes y varias secciones', () async {
    final bytes = await generateReportPdf(report());
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    // Para revisar el diseño a mano: REPORTE_PDF_SALIDA=<carpeta>.
    final output = Platform.environment['REPORTE_PDF_SALIDA'];
    if (output != null) {
      File('$output/reporte_area.pdf').writeAsBytesSync(bytes);
      File('$output/reporte_general.pdf').writeAsBytesSync(
        await generateReportPdf(report(type: ReportType.general)),
      );
    }
  });

  test('el nombre del archivo no lleva tildes ni espacios', () {
    expect(report().fileName, 'reporte_de_area_desarrollo_octubre_2026.pdf');
  });
}
