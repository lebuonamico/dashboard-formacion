import 'package:app_finnegans/features/areas/domain/areas_service.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_level.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:flutter_test/flutter_test.dart';

EmployeeCompliance _member(
  String employeeId, {
  String firstName = 'Persona',
  String area = 'Desarrollo',
  String team = 'Core',
  double soft = 0,
  double business = 0,
  double requiredSoft = 10,
}) => const EmployeeComplianceService().summarize(
  employee: Employee(
    employeeId: employeeId,
    firstName: firstName,
    lastName: employeeId,
    seniority: Seniority.junior1,
    area: area,
    email: 'p$employeeId@finnegans.com',
    team: team,
    isActive: true,
  ),
  creditedHours: {
    CourseCategory.softSkills: soft,
    CourseCategory.businessSkills: business,
  },
  declaredHours: {CourseCategory.softSkills: soft},
  requiredHours: {
    CourseCategory.softSkills: requiredSoft,
    CourseCategory.businessSkills: business,
  },
);

TeamOverview _team(String area, String name) => TeamOverview(
  id: '$area-$name',
  name: name,
  area: area,
  leader: '',
  memberCount: 1,
  membersOnTarget: 0,
  completedHours: 0,
  targetHours: 0,
  hoursDeviation: 0,
  businessHours: 0,
  softSkillsHours: 0,
  explorationHours: 0,
  teachingHours: 0,
  averageHoursPerMember: 0,
  completionPercentage: 0,
  status: TeamStatus.critical,
);

void main() {
  const service = AreasService();

  group('summarize', () {
    test('Suma horas, objetivo, desvío y categorías del área', () {
      final area = service.summarize('Desarrollo', [
        _member('1', soft: 10, business: 2, team: ' Core '),
        _member('2', soft: 4, team: 'Mobile'),
        _member('3', soft: 1, team: ''),
      ], leaders: 'Ana');

      expect(area.name, 'Desarrollo');
      expect(area.generalTeams, ['Core', 'Mobile']);
      expect(area.memberCount, 3);
      expect(area.membersOnTarget, 1);
      expect(area.completedHours, 17);
      expect(area.targetHours, 32);
      expect(area.hoursDeviation, -15);
      expect(area.softSkillsHours, 15);
      expect(area.businessHours, 2);
      expect(area.compliancePercentage, closeTo(53.125, 1e-9));
      expect(area.level, ComplianceLevel.critical);
      expect(area.leaders, 'Ana');
    });

    test('Un legajo repetido en el anual cuenta una vez y si alguna etapa '
        'no cumple no está en objetivo', () {
      final area = service.summarize('Desarrollo', [
        _member('1', soft: 10, team: 'Core'),
        _member('1', soft: 2, team: 'Mobile'),
        _member('2', soft: 10),
      ]);

      expect(area.memberCount, 2);
      expect(area.membersOnTarget, 1);
    });

    test('Sin objetivo el cumplimiento es 100 %', () {
      final area = service.summarize('Dirección', [
        _member('1', requiredSoft: 0),
      ]);

      expect(area.compliancePercentage, 100);
      expect(area.level, ComplianceLevel.onTarget);
    });
  });

  group('buildPeriodSummary', () {
    final compliance = [
      _member('1', area: 'Ventas', soft: 10),
      _member('2', area: 'Soporte', soft: 8),
      _member('3', area: 'Desarrollo', soft: 1),
      _member('4', area: 'Datos', soft: 2),
    ];

    test('Lo que peor está primero: estado, porcentaje y nombre', () {
      final summary = service.buildPeriodSummary(compliance);

      expect(summary.areas.map((area) => area.name), [
        'Desarrollo',
        'Datos',
        'Soporte',
        'Ventas',
      ]);
    });

    test('Totales y conteos por estado', () {
      final summary = service.buildPeriodSummary(
        compliance,
        resolveLeaders: (area) => area == 'Ventas' ? 'Ana' : null,
      );

      expect(summary.hasData, isTrue);
      expect(summary.areaCount, 4);
      expect(summary.employeeCount, 4);
      expect(summary.completedHours, 21);
      expect(summary.targetHours, 40);
      expect(summary.hoursDeviation, -19);
      expect(summary.overallCompletion, closeTo(52.5, 1e-9));
      expect(summary.softSkillsHours, 21);
      expect(summary.onTarget, 1);
      expect(summary.atRisk, 1);
      expect(summary.critical, 2);
      expect(summary.areas.last.leaders, 'Ana');
    });

    test('Sin cumplimiento no hay áreas ni porcentaje', () {
      final summary = service.buildPeriodSummary(const []);

      expect(summary.areas, isEmpty);
      expect(summary.overallCompletion, 0);
    });
  });

  group('getAreaDetail', () {
    test('Busca el área sin espacios ni mayúsculas y ordena por nombre', () {
      final detail = service.getAreaDetail(
        compliance: [
          _member('1', firstName: 'Zoe', area: 'Desarrollo'),
          _member('2', firstName: 'Ana', area: 'Desarrollo'),
          _member('3', area: 'Ventas'),
        ],
        teams: [_team('Desarrollo', 'Core'), _team('Ventas', 'Norte')],
        area: '  desarrollo ',
        resolveLeaders: (area) => 'Líder de $area',
      )!;

      expect(detail.area.name, 'Desarrollo');
      expect(detail.area.leaders, 'Líder de Desarrollo');
      expect(detail.members.map((m) => m.employee.firstName), ['Ana', 'Zoe']);
      expect(detail.teams.map((team) => team.name), ['Core']);
    });

    test('Un área sin integrantes elegibles no tiene detalle', () {
      expect(
        service.getAreaDetail(
          compliance: [_member('1', area: 'Ventas')],
          teams: const [],
          area: 'Desarrollo',
        ),
        isNull,
      );
    });
  });

  test('byCompliance ordena de mayor a menor y por nombre si empatan', () {
    final summary = service.buildPeriodSummary([
      _member('1', area: 'B', soft: 5),
      _member('2', area: 'A', soft: 5),
      _member('3', area: 'C', soft: 9),
    ]);

    expect(service.byCompliance(summary.areas).map((area) => area.name), [
      'C',
      'A',
      'B',
    ]);
  });

  test('El filtro por niveles deja solo esos niveles; vacío deja todos', () {
    final members = [
      _member('1', soft: 10),
      _member('2', soft: 8),
      _member('3', soft: 1),
    ];

    expect(service.levelsPresent(members), ComplianceLevel.values.toSet());
    expect(
      service
          .membersAtLevels(members, {ComplianceLevel.critical})
          .map((m) => m.employee.employeeId),
      ['3'],
    );
    expect(service.membersAtLevels(members, const {}), members);
  });
}
