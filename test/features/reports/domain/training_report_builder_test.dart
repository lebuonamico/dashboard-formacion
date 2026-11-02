import 'package:app_finnegans/features/areas/domain/area_summary.dart';
import 'package:app_finnegans/features/areas/domain/areas_service.dart';
import 'package:app_finnegans/features/dashboard/domain/dashboard_kpis_service.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:app_finnegans/features/reports/domain/training_report_builder.dart';
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

const _builder = TrainingReportBuilder();

TrainingReport _report(
  List<EmployeeCompliance> members, {
  ReportType type = ReportType.area,
  List<ReportBreakdownRow> breakdown = const [],
}) => _builder.build(
  type: type,
  title: 'Desarrollo',
  period: 'Octubre 2026',
  memberCount: members.length,
  onTarget: 0,
  hours: 0,
  target: 0,
  percentage: 0,
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
  level: _builder.levelFor(percentage),
);

void main() {
  test('El semáforo corta en 100 y 70', () {
    expect(_builder.levelFor(100), ReportLevel.ok);
    expect(_builder.levelFor(99.9), ReportLevel.attention);
    expect(_builder.levelFor(70), ReportLevel.attention);
    expect(_builder.levelFor(69.9), ReportLevel.critical);
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
    final byType = {for (final c in report.hoursByCategory) c.category: c};

    expect(
      report.hoursByCategory.map((c) => c.category),
      CourseCategory.values,
    );
    expect(byType[_business]!.credited, 5);
    expect(byType[_business]!.target, 8);
    expect(byType[_exploration]!.credited, 0);
    expect(byType[_exploration]!.target, 0);
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

  test('El tipo decide la ubicación de cada integrante', () {
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

    expect(report.breakdown.map((f) => f.name), ['Mobile', 'Core', 'Web']);
  });

  group('Por tipo de reporte', () {
    TeamOverview overview({
      String name = 'Core',
      double percentage = 50,
      TeamStatus status = TeamStatus.atRisk,
    }) => TeamOverview(
      id: 'desarrollo-$name',
      name: name,
      area: 'Desarrollo',
      leader: 'María López',
      memberCount: 2,
      membersOnTarget: 1,
      completedHours: 8,
      targetHours: 16,
      hoursDeviation: -8,
      businessHours: 4,
      softSkillsHours: 4,
      explorationHours: 0,
      teachingHours: 0,
      averageHoursPerMember: 4,
      completionPercentage: percentage,
      status: status,
    );

    test('El de equipo usa el estado del equipo, no solo el porcentaje', () {
      final report = _builder.team(
        period: 'Octubre 2026',
        detail: TeamDetail(overview: overview(), members: const []),
      );

      expect(report.type, ReportType.team);
      expect(report.title, 'Core');
      expect(report.area, 'Desarrollo');
      expect(report.leaders, 'María López');
      expect(report.percentage, 50);
      expect(report.level, ReportLevel.attention);
      expect(report.breakdown, isEmpty);
    });

    test('El de área desglosa sus equipos de menor a mayor', () {
      final members = [_member('Ana Pérez', business: 4, softSkills: 4)];
      final report = _builder.area(
        period: 'Octubre 2026',
        detail: AreaDetail(
          area: const AreasService().summarize(
            'Desarrollo',
            members,
            leaders: 'Ana Pérez',
          ),
          teams: [
            overview(name: 'Web', percentage: 100, status: TeamStatus.onTarget),
            overview(percentage: 40, status: TeamStatus.critical),
          ],
          members: members,
        ),
      );

      expect(report.title, 'Desarrollo');
      expect(report.leaders, 'Ana Pérez');
      expect(report.teamCount, 2);
      expect(report.onTarget, 1);
      expect(report.level, ReportLevel.ok);
      expect(report.breakdown.map((row) => (row.name, row.level)), [
        ('Core', ReportLevel.critical),
        ('Web', ReportLevel.ok),
      ]);
    });

    test('El general cuenta una vez a quien cumple en varias etapas', () {
      final ana = _member('Ana Pérez', business: 4, softSkills: 4);
      final report = _builder.general(
        title: 'Plan de formación interna',
        period: 'Año 2026',
        kpis: DashboardKpisService().calculate(
          complianceList: [ana, ana],
          timeEntries: const [],
          evaluatedMonths: 1,
        ),
        areaCount: 1,
        teamCount: 2,
        areas: const [],
        members: [ana, ana],
      );

      expect(report.type, ReportType.general);
      expect(report.memberCount, 1);
      expect(report.onTarget, 1);
      expect(report.areaCount, 1);
      expect(report.teamCount, 2);
      expect(report.trainingCount, 0);
      expect(report.level, ReportLevel.ok);
    });
  });
}
