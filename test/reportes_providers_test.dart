import 'package:app_finnegans/domain/modelos/reporte_formacion.dart';
import 'package:app_finnegans/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/providers/reportes_providers.dart';
import 'package:app_finnegans/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _teamSection = (area: 'Desarrollo', team: 'Core');

TeamOverview _team({
  String name = 'Core',
  String leader = 'María López',
  double percentage = 50,
  TeamStatus status = TeamStatus.critical,
}) => TeamOverview(
  id: 'desarrollo-$name',
  name: name,
  area: 'Desarrollo',
  leader: leader,
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

const _area = AreaGlobalViewModel(
  name: 'Desarrollo',
  generalTeams: ['Core', 'Mobile'],
  memberCount: 4,
  membersOnTarget: 1,
  completedHours: 20,
  targetHours: 32,
  businessHours: 10,
  softSkillsHours: 10,
  explorationHours: 0,
  teachingHours: 0,
  compliancePercentage: 62.5,
  level: ComplianceLevel.critical,
  leaders: 'Ana Pérez',
);

ProviderContainer _container({
  bool hasData = true,
  TeamDetail? team,
  AreaDetailViewModel? area,
  bool projectionFails = false,
}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      hasTeamPeriodDataProvider.overrideWith((ref) async => hasData),
      teamDetailProvider(_teamSection).overrideWith((ref) async => team),
      areaDetailProvider('Desarrollo').overrideWith((ref) async => area),
      annualProjectionProvider.overrideWith(
        (ref, section) async =>
            projectionFails ? throw StateError('sin cargas') : null,
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(periodScopeProvider.notifier).state = PeriodScope.monthly;
  container.read(periodMonthFilterProvider.notifier).state = 10;
  container.read(periodYearFilterProvider.notifier).state = 2026;
  return container;
}

void main() {
  test('Sin datos en el período no hay reporte en ninguna pantalla', () async {
    final container = _container(
      hasData: false,
      team: TeamDetail(overview: _team(), members: const []),
    );

    expect(await container.read(dashboardReportProvider.future), isNull);
    expect(
      await container.read(areaReportProvider('Desarrollo').future),
      isNull,
    );
    expect(
      await container.read(teamReportProvider(_teamSection).future),
      isNull,
    );
  });

  test('Sin colaboradores elegibles no hay reporte del equipo', () async {
    final container = _container();

    expect(
      await container.read(teamReportProvider(_teamSection).future),
      isNull,
    );
  });

  test('El reporte del equipo usa los números de su detalle', () async {
    final container = _container(
      team: TeamDetail(overview: _team(), members: const []),
    );

    final report = await container.read(
      teamReportProvider(_teamSection).future,
    );

    expect(report!.type, ReportType.team);
    expect(report.title, 'Core');
    expect(report.details, ['Área: Desarrollo', 'Líder: María López']);
    expect(report.period, 'Octubre 2026');
    expect(report.percentage, 50);
    expect(report.status, 'Crítico');
    expect(report.level, ReportLevel.critical);
    expect(report.breakdown, isEmpty);
  });

  test('El reporte del área desglosa sus equipos', () async {
    final container = _container(
      area: AreaDetailViewModel(
        area: _area,
        teams: [
          _team(),
          _team(name: 'Mobile', percentage: 100, status: TeamStatus.onTarget),
        ],
        members: const [],
      ),
    );

    final report = await container.read(
      areaReportProvider('Desarrollo').future,
    );

    expect(report!.type, ReportType.area);
    expect(report.details, ['Líder: Ana Pérez', '2 equipos']);
    expect(report.level, ReportLevel.critical);
    expect(report.breakdown.map((f) => (f.name, f.level)), [
      ('Core', ReportLevel.critical),
      ('Mobile', ReportLevel.ok),
    ]);
  });

  test('Si la proyección falla, el reporte sale sin ella', () async {
    final container = _container(
      team: TeamDetail(overview: _team(), members: const []),
      projectionFails: true,
    );

    final report = await container.read(
      teamReportProvider(_teamSection).future,
    );

    expect(report, isNotNull);
    expect(report!.projection, isNull);
  });

  test('En el anual el período aclara que suma los meses con datos', () async {
    final container = _container(
      team: TeamDetail(overview: _team(), members: const []),
    );
    container.read(periodScopeProvider.notifier).state = PeriodScope.annual;

    final report = await container.read(
      teamReportProvider(_teamSection).future,
    );

    expect(report!.period, 'Año 2026 · meses con datos');
  });
}
