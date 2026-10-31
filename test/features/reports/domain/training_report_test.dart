import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/reports/domain/training_report.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';

const _business = CourseCategory.businessSkills;
const _softSkills = CourseCategory.softSkills;
const _exploration = CourseCategory.exploration;

/// Requiere 4 h de Negocio y 4 de Blandas, nada de Libres ni Dictado.
EmployeeCompliance _member(
  String name, {
  double business = 0,
  double softSkills = 0,
  double exploration = 0,
}) {
  final parts = name.split(' ');
  return const EmployeeComplianceService().summarize(
    employee: Employee(
      employeeId: name,
      firstName: parts.first,
      lastName: parts.last,
      seniority: Seniority.junior1,
      area: 'Desarrollo',
      email: '${parts.first}@example.com',
      team: 'Core',
    ),
    creditedHours: {
      _business: business,
      _softSkills: softSkills,
      _exploration: exploration,
    },
    declaredHours: const {},
    requiredHours: const {
      _business: 4,
      _softSkills: 4,
      _exploration: 0,
      CourseCategory.teaching: 0,
    },
  );
}

TrainingReport _report(
  List<EmployeeCompliance> members, {
  ReportType type = ReportType.area,
  List<ReportBreakdownRow> breakdown = const [],
  String title = 'Desarrollo',
  String period = 'Octubre 2026',
}) => TrainingReport(
  type: type,
  title: title,
  period: period,
  memberCount: members.length,
  onTarget: 0,
  hours: 0,
  target: 0,
  percentage: 0,
  status: 'Crítico',
  level: ReportLevel.critical,
  members: members,
  breakdown: breakdown,
);

ReportBreakdownRow _row(String name, double percentage) => ReportBreakdownRow(
  name: name,
  memberCount: 1,
  hours: 0,
  target: 0,
  percentage: percentage,
  status: '',
  level: reportLevelFor(percentage),
);

void main() {
  test('El semáforo corta en 100 y 70', () {
    expect(reportLevelFor(100), ReportLevel.ok);
    expect(reportLevelFor(99.9), ReportLevel.attention);
    expect(reportLevelFor(70), ReportLevel.attention);
    expect(reportLevelFor(69.9), ReportLevel.critical);
  });

  test('Cuenta a cada persona en su nivel, con los tres niveles siempre', () {
    final report = _report([
      _member('Ana Pérez', business: 4, softSkills: 4), // 100 %
      _member('Bruno Gómez', business: 4, softSkills: 2), // 75 %
      _member('Carla Núñez', business: 1), // 12.5 %
    ]);

    expect(report.countByLevel, {
      ReportLevel.ok: 1,
      ReportLevel.attention: 1,
      ReportLevel.critical: 1,
    });
    expect(_report(const []).countByLevel.values, everyElement(0));
  });

  test('Las horas por categoría se topean al objetivo de cada persona', () {
    final report = _report([
      // 6 h de Negocio con 4 requeridas: suma 4. Libres no es requerida.
      _member('Ana Pérez', business: 6, exploration: 3),
      _member('Bruno Gómez', business: 1),
    ]);
    final byType = {for (final c in report.hoursByCategory) c.tipo: c};

    expect(report.hoursByCategory.map((c) => c.tipo), CourseCategory.values);
    expect(byType[_business]!.validas, 5);
    expect(byType[_business]!.objetivo, 8);
    expect(byType[_exploration]!.validas, 0);
    expect(byType[_exploration]!.objetivo, 0);
  });

  test('Lista de menor a mayor cumplimiento y por nombre si empatan', () {
    final report = _report([
      _member('Ana Pérez', business: 4, softSkills: 4),
      _member('Diego Ruiz'),
      _member('Bruno Gómez'),
      _member('Carla Núñez', business: 4, softSkills: 2),
    ]);

    expect(report.listedMembers.map((m) => m.employee.firstName), [
      'Bruno',
      'Diego',
      'Carla',
      'Ana',
    ]);
  });

  test('El general lista solo a los críticos', () {
    final members = [
      _member('Ana Pérez', business: 4, softSkills: 4),
      _member('Bruno Gómez', business: 4, softSkills: 2),
      _member('Carla Núñez', business: 1),
    ];

    final general = _report(members, type: ReportType.general);
    expect(general.criticalOnly, isTrue);
    expect(general.listedMembers.map((m) => m.employee.firstName), ['Carla']);
    expect(_report(members).listedMembers, hasLength(3));
  });

  test('El tipo decide el desglose y la ubicación de cada integrante', () {
    expect(ReportType.general.breakdownTitle, 'Cumplimiento por área');
    expect(ReportType.area.breakdownTitle, 'Cumplimiento por equipo');
    expect(ReportType.team.breakdownTitle, isNull);

    expect(
      _report(const [], type: ReportType.general).memberLocation,
      MemberLocation.teamAreaY,
    );
    expect(_report(const []).memberLocation, MemberLocation.team);
    expect(
      _report(const [], type: ReportType.team).memberLocation,
      MemberLocation.none,
    );
  });

  test('El desglose va de menor a mayor cumplimiento', () {
    final report = _report(
      const [],
      breakdown: [_row('Core', 80), _row('Mobile', 40), _row('Web', 100)],
    );

    expect(report.sortedBreakdown.map((f) => f.name), [
      'Mobile',
      'Core',
      'Web',
    ]);
    expect(report.breakdown.first.name, 'Core');
  });

  test('El nombre del archivo no lleva tildes, eñes ni símbolos', () {
    final report = _report(
      const [],
      title: 'Diseño & Núñez',
      period: 'Año 2026 · meses con datos',
    );

    expect(
      report.fileName,
      'reporte_de_area_diseno_nunez_ano_2026_meses_con_datos.pdf',
    );
  });
}
