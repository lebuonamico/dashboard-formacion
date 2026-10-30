import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_repository.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure_repository.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_repository.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/assistant/presentation/providers/assistant_data_provider.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/teams/presentation/providers/teams_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _year = 2026;

class _FakeEmployees implements EmployeesRepository {
  final List<Employee> employees;
  _FakeEmployees(this.employees);

  @override
  Future<List<Employee>> getEmployees({
    String? employeeId,
    String? team,
    String? sector,
  }) async => employees;

  @override
  Future<void> replaceEmployees(List<Employee> employees) async {}

  @override
  Future<void> resetToMock() async {}
}

class _FakeEmployeesWithHistory extends _FakeEmployees
    implements EmployeeHistoryRepository {
  final List<EmployeeHistoryEntry> history;
  _FakeEmployeesWithHistory(super.employees, this.history);

  @override
  Future<List<EmployeeHistoryEntry>> getEmployeeHistory() async => history;
}

class _FakeCourses implements CoursesRepository {
  @override
  Future<List<Course>> getCourses({String? id, String? name}) async => [
    _course,
  ];

  @override
  Future<void> replaceCourses(List<Course> courses) async {}

  @override
  Future<void> resetToMock() async {}
}

class _FakeTimeEntries implements CrmTimeEntriesRepository {
  final List<CrmTimeEntry> timeEntries;
  _FakeTimeEntries(this.timeEntries);

  @override
  Future<List<CrmTimeEntry>> getTimeEntries({
    String? employeeId,
    String? courseId,
    DateTime? from,
    DateTime? until,
  }) async => timeEntries
      .where(
        (timeEntry) =>
            (from == null || !timeEntry.date.isBefore(from)) &&
            (until == null || timeEntry.date.isBefore(until)),
      )
      .toList();

  @override
  Future<void> replaceTimeEntries(List<CrmTimeEntry> timeEntries) async {}

  @override
  Future<void> resetToMock() async {}
}

class _FakeCertifications implements LmsCertificationsRepository {
  final List<LmsCertification> certifications;
  _FakeCertifications(this.certifications);

  @override
  Future<List<LmsCertification>> getCertifications({
    String? employeeId,
    String? courseId,
  }) async => certifications;

  @override
  Future<void> replaceCertifications(
    List<LmsCertification> certifications,
  ) async {}
}

class _FakeStructure implements OrgStructureRepository {
  final OrgStructure structure;
  _FakeStructure(this.structure);

  @override
  Future<OrgStructure> getStructure() async => structure;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final _course = Course(
  id: '1',
  name: 'Negociación',
  category: CourseCategory.businessSkills,
  courseArea: '',
  instructorEmployeeId: '',
  workloadHours: 4,
);

Employee _employee(String employeeId, String sector, String team) => Employee(
  employeeId: employeeId,
  firstName: 'Persona',
  lastName: employeeId,
  seniority: Seniority.junior1,
  area: sector,
  email: 'persona$employeeId@finnegans.com',
  team: team,
  manager: 'Gerente $team',
  hireDate: DateTime(2020, 1, 1),
);

/// 1 y 2 en PLATAFORMA CORE y BACKEND, de PRODUCTOS TECNOLÓGICOS; 3 en SOPORTE
/// y 4 sin equipo, de SERVICIOS.
final _employees = [
  Employee(
    employeeId: '1',
    firstName: 'Lía',
    lastName: 'Líder',
    seniority: Seniority.junior1,
    area: 'PRODUCTOS TECNOLÓGICOS',
    email: 'Lider@finnegans.com',
    team: 'PLATAFORMA CORE',
    manager: 'Gerente Core',
    hireDate: DateTime(2020, 1, 1),
  ),
  _employee('2', 'PRODUCTOS TECNOLÓGICOS', 'BACKEND'),
  _employee('3', 'SERVICIOS', 'SOPORTE'),
  _employee('4', 'SERVICIOS', ''),
];

OrgStructure _structure({
  Set<String> coreLeaders = const {'lider@finnegans.com'},
}) => OrgStructure(
  areas: [
    Area(id: '1', name: 'PRODUCTOS TECNOLÓGICOS'),
    Area(id: '2', name: 'SERVICIOS', leaders: {'area@finnegans.com'}),
  ],
  teams: [
    Team(id: '10', areaId: '1', name: 'PLATAFORMA CORE', leaders: coreLeaders),
    Team(id: '11', areaId: '1', name: 'BACKEND'),
    Team(id: '20', areaId: '2', name: 'SOPORTE'),
  ],
);

List<CrmTimeEntry> _timeEntries(Iterable<String> employeeIds, int month) => [
  for (final employeeId in employeeIds)
    CrmTimeEntry(
      id: 'tx-$employeeId-$month',
      courseName: _course.name,
      employeeId: employeeId,
      date: DateTime(_year, month, 10),
      hours: 4,
      kind: TimeEntryKind.taken,
    ),
];

List<LmsCertification> _completions(Iterable<String> employeeIds, int month) =>
    [
      for (final employeeId in employeeIds)
        LmsCertification(
          employeeId: employeeId,
          courseName: _course.name,
          isCompleted: true,
          completedAt: DateTime(_year, month, 20),
        ),
    ];

/// Sin versiones: rige el plan por defecto, como antes de poder editarlo.
class _PlanFake implements TrainingPlanRepository {
  @override
  Future<TrainingPlanHistory> getPlans() async =>
      const TrainingPlanHistory.empty();

  @override
  Future<void> saveVersion(TrainingPlanVersion version) async {}
}

ProviderContainer _container({
  required bool enabled,
  String? email,
  String? role,
  OrgStructure? structure,
  List<Employee>? employees,
  List<EmployeeHistoryEntry>? history,
  List<CrmTimeEntry>? timeEntries,
  List<LmsCertification>? certifications,
  int month = 6,
}) {
  final payroll = employees ?? _employees;
  final employeeIds = payroll.map((employee) => employee.employeeId);
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(null)),
      sessionDataProvider.overrideWithValue((
        enabled: enabled,
        email: email,
        role: role,
      )),
      orgStructureRepositoryProvider.overrideWithValue(
        structure == null ? null : _FakeStructure(structure),
      ),
      employeesRepositoryProvider.overrideWithValue(
        history == null
            ? _FakeEmployees(payroll)
            : _FakeEmployeesWithHistory(payroll, history),
      ),
      coursesRepositoryProvider.overrideWithValue(_FakeCourses()),
      trainingPlanRepositoryProvider.overrideWithValue(_PlanFake()),
      crmTimeEntriesRepositoryProvider.overrideWithValue(
        _FakeTimeEntries(timeEntries ?? _timeEntries(employeeIds, 6)),
      ),
      lmsCertificationsRepositoryProvider.overrideWithValue(
        _FakeCertifications(certifications ?? _completions(employeeIds, 6)),
      ),
      periodScopeProvider.overrideWith((ref) => PeriodScope.monthly),
      periodMonthFilterProvider.overrideWith((ref) => month),
      periodYearFilterProvider.overrideWith((ref) => _year),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Un líder ve solo su equipo', () async {
    final container = _container(
      enabled: true,
      email: 'lider@finnegans.com',
      role: 'teamLead',
      structure: _structure(),
    );

    final employees = await container.read(employeesProvider.future);
    expect(employees.map((e) => e.employeeId), ['1']);

    final timeEntries = await container.read(crmTimeEntriesProvider.future);
    expect(timeEntries.map((c) => c.employeeId), ['1']);
    final dashboard = await container.read(dashboardTimeEntriesProvider.future);
    expect(dashboard.map((c) => c.employeeId), ['1']);
    final certifications = await container.read(
      lmsCertificationsProvider.future,
    );
    expect(certifications.map((c) => c.employeeId), ['1']);

    final summary = await container.read(teamsPeriodSummaryProvider.future);
    expect(summary.teams, hasLength(1));
    expect(summary.teams.single.name, 'PLATAFORMA CORE');
    expect(summary.teams.single.area, 'PRODUCTOS TECNOLÓGICOS');
    // El email del líder coincide con el de la nómina: se ve su nombre.
    expect(summary.teams.single.leader, 'Lía Líder');
  });

  test('Un usuario de área ve toda su área, sin equipo incluidos', () async {
    final container = _container(
      enabled: true,
      email: 'Area@Finnegans.com',
      role: 'areaLead',
      structure: _structure(),
    );

    final employees = await container.read(employeesProvider.future);
    expect(employees.map((e) => e.employeeId), ['3', '4']);

    final areas = await container.read(areasPeriodSummaryProvider.future);
    expect(areas.areas.map((area) => area.name), ['SERVICIOS']);
    // No hay empleado con ese email: se muestra el email.
    expect(areas.areas.single.leaders, 'area@finnegans.com');

    final teams = await container.read(teamsPeriodSummaryProvider.future);
    expect(teams.teams.map((team) => team.name).toSet(), {
      'SOPORTE',
      'Sin equipo asignado',
    });
  });

  test(
    'Academia ve toda la empresa y los equipos sin líder caen al Gerente',
    () async {
      final container = _container(
        enabled: true,
        email: 'academia@finnegans.com',
        role: 'academy',
        structure: _structure(),
      );

      expect(await container.read(visibleEmployeeIdsProvider.future), isNull);
      final employees = await container.read(employeesProvider.future);
      expect(employees.map((e) => e.employeeId), ['1', '2', '3', '4']);

      final summary = await container.read(teamsPeriodSummaryProvider.future);
      final backend = summary.teams.firstWhere((e) => e.name == 'BACKEND');
      expect(backend.leader, 'Gerente BACKEND');
      final core = summary.teams.firstWhere((e) => e.name == 'PLATAFORMA CORE');
      expect(core.leader, 'Lía Líder');
    },
  );

  test(
    'El contexto del asistente IA conserva el alcance de la sesión',
    () async {
      final container = _container(
        enabled: true,
        email: 'lider@finnegans.com',
        role: 'teamLead',
        structure: _structure(),
      );

      final context = await container.read(prepareAiContextProvider)(
        const AssistantDestination(AssistantModule.dashboard),
        '¿Cómo viene el cumplimiento general?',
      );

      final result =
          (context.data['resultados'] as List).single as Map<String, Object?>;
      expect(result['tiene_datos'], isTrue);
      expect((result['global'] as Map)['colaboradores'], 1);
      expect((result['dashboard'] as Map)['colaboradores'], 1);
    },
  );

  test('Un líder sin equipos asignados no ve datos', () async {
    final container = _container(
      enabled: true,
      email: 'nuevo@finnegans.com',
      role: 'teamLead',
      structure: _structure(),
    );

    expect(await container.read(employeesProvider.future), isEmpty);
    expect(await container.read(crmTimeEntriesProvider.future), isEmpty);
    expect(await container.read(lmsCertificationsProvider.future), isEmpty);
  });

  test(
    'Pertenece a sale de la nómina aunque no esté en lo que lidera',
    () async {
      // Lidera PLATAFORMA CORE, pero en la nómina figura en SOPORTE.
      final container = _container(
        enabled: true,
        email: 'PERSONA3@finnegans.com',
        role: 'teamLead',
        structure: _structure(coreLeaders: {'persona3@finnegans.com'}),
      );

      final employees = await container.read(employeesProvider.future);
      expect(employees.map((e) => e.employeeId), ['1']);
      final own = await container.read(sessionEmployeeProvider.future);
      expect(own!.employeeId, '3');
      expect(own.team, 'SOPORTE');
      expect(own.area, 'SERVICIOS');
    },
  );

  test('Sin fila en la nómina, Pertenece a queda vacío', () async {
    final container = _container(
      enabled: true,
      email: 'externo@gmail.com',
      role: 'teamLead',
      structure: _structure(),
    );
    expect(await container.read(sessionEmployeeProvider.future), isNull);
  });

  test('En modo local se ve todo y no hay sesión que buscar', () async {
    final container = _container(enabled: false);

    expect(await container.read(orgStructureProvider.future), isNull);
    expect(await container.read(visibleEmployeeIdsProvider.future), isNull);
    expect(await container.read(sessionEmployeeProvider.future), isNull);
    final employees = await container.read(employeesProvider.future);
    expect(employees.map((e) => e.employeeId), ['1', '2', '3', '4']);

    final summary = await container.read(teamsPeriodSummaryProvider.future);
    expect(
      summary.teams.firstWhere((e) => e.name == 'PLATAFORMA CORE').leader,
      'Gerente Core',
    );
  });

  group('Con historial', () {
    // La persona 2 hoy está en PLATAFORMA CORE, pero hasta junio estuvo en
    // BACKEND.
    final history = [
      EmployeeHistoryEntry(
        employeeId: '1',
        seniority: Seniority.junior1,
        area: 'PRODUCTOS TECNOLÓGICOS',
        team: 'PLATAFORMA CORE',
        manager: 'Gerente Core',
        isActive: true,
        validFrom: DateTime(2020, 1, 1),
      ),
      EmployeeHistoryEntry(
        employeeId: '2',
        seniority: Seniority.junior1,
        area: 'PRODUCTOS TECNOLÓGICOS',
        team: 'BACKEND',
        manager: 'Gerente BACKEND',
        isActive: true,
        validFrom: DateTime(2020, 1, 1),
        validTo: DateTime(_year, 7, 1),
      ),
      EmployeeHistoryEntry(
        employeeId: '2',
        seniority: Seniority.junior1,
        area: 'PRODUCTOS TECNOLÓGICOS',
        team: 'PLATAFORMA CORE',
        manager: 'Gerente Core',
        isActive: true,
        validFrom: DateTime(_year, 7, 1),
      ),
    ];

    ProviderContainer container(int month) => _container(
      enabled: true,
      email: 'lider@finnegans.com',
      role: 'teamLead',
      structure: _structure(),
      // La nómina actual pone a la persona 2 en PLATAFORMA CORE.
      employees: [
        _employees[0],
        _employee('2', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'),
      ],
      history: history,
      timeEntries: [
        ..._timeEntries(['1', '2'], 6),
        ..._timeEntries(['1', '2'], 7),
      ],
      certifications: [
        ..._completions(['1', '2'], 6),
        ..._completions(['1', '2'], 7),
      ],
      month: month,
    );

    test(
      'El líder ve a alguien solo en los meses en que estuvo en su equipo',
      () async {
        final june = container(6);
        final juneComplianceList = await june.read(
          teamComplianceProvider.future,
        );
        expect(juneComplianceList.map((c) => c.employee.employeeId), ['1']);

        final july = container(7);
        final julyComplianceList = await july.read(
          teamComplianceProvider.future,
        );
        expect(julyComplianceList.map((c) => c.employee.employeeId).toSet(), {
          '1',
          '2',
        });
        expect(julyComplianceList.map((c) => c.employee.team).toSet(), {
          'PLATAFORMA CORE',
        });
      },
    );

    test(
      'El asistente IA reconstruye el período con el alcance del líder',
      () async {
        // Su contenedor no tiene padre: si armara su propia sesión, en junio
        // contaría también a la persona 2, que estaba en Backend.
        final context = await container(6).read(prepareAiContextProvider)(
          const AssistantDestination(AssistantModule.dashboard),
          '¿Cómo viene el cumplimiento general?',
        );

        final result =
            (context.data['resultados'] as List).single as Map<String, Object?>;
        expect((result['global'] as Map)['colaboradores'], 1);
      },
    );
  });
}
