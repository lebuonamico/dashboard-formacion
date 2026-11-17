import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_context_builder.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_data.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query.dart';
import 'package:app_finnegans/features/assistant/domain/assistant_query_planner.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';
import 'package:flutter_test/flutter_test.dart';

const _dashboard = AssistantDestination(AssistantModule.dashboard);
const _general = '¿Cómo viene el cumplimiento general?';

Employee _employee(String id, String team, {DateTime? hireDate}) => Employee(
  employeeId: id,
  firstName: 'Persona',
  lastName: id,
  seniority: Seniority.junior1,
  area: 'Desarrollo',
  email: '$id@finnegans.com',
  team: team,
  hireDate: hireDate ?? DateTime(2025, 1, 1),
);

LmsCertification _completion(String employeeId, int month) => LmsCertification(
  employeeId: employeeId,
  courseName: 'Negociación',
  isCompleted: true,
  completedAt: DateTime(2026, month, 20),
);

AssistantData _data({
  List<Employee>? employees,
  List<EmployeeHistoryEntry>? history,
  List<LmsCertification>? certifications,
  UserScope scope = const UserScope.total(),
}) {
  final payroll =
      employees ?? [_employee('1', 'Backend'), _employee('2', 'Frontend')];
  return AssistantData(
    employees: payroll,
    // Like the in-memory repository: one validity per employee.
    history:
        history ??
        [
          for (final employee in payroll)
            _validity(employee.employeeId, employee.team, DateTime(2020)),
        ],
    courses: [
      Course(
        id: 'negociacion',
        name: 'Negociación',
        category: CourseCategory.businessSkills,
        courseArea: '',
        instructorEmployeeId: '',
        workloadHours: 4,
      ),
    ],
    timeEntries: const [],
    certifications:
        certifications ?? [_completion('1', 7), _completion('2', 7)],
    scope: scope,
    complianceService: ComplianceService(),
  );
}

EmployeeHistoryEntry _validity(
  String id,
  String team,
  DateTime from, [
  DateTime? to,
]) => EmployeeHistoryEntry(
  employeeId: id,
  seniority: Seniority.junior1,
  area: 'Desarrollo',
  team: team,
  manager: '',
  isActive: true,
  validFrom: from,
  validTo: to,
);

Future<AssistantContext> _build(
  String question, {
  AssistantDestination destination = _dashboard,
  int month = 7,
  bool dynamic = true,
  required AssistantDataLoader loadData,
}) => AssistantContextBuilder().build(
  const AssistantQueryPlanner().plan(
    question,
    destination,
    PeriodFilter(scope: PeriodScope.monthly, month: month, year: 2026),
  ),
  dynamic: dynamic,
  loadData: loadData,
);

Map<String, Object?> _result(AssistantContext context) =>
    (context.data['resultados'] as List).single as Map<String, Object?>;

Future<AssistantData> _unavailable() async => throw StateError('sin datos');

void main() {
  group('AssistantContextBuilder', () {
    test('el global respeta el alcance de la sesión', () async {
      final context = await _build(
        _general,
        loadData: () async => _data(
          scope: const UserScope(teamKeys: {('desarrollo', 'backend')}),
        ),
      );

      expect((_result(context)['global'] as Map)['colaboradores'], 1);
    });

    test('con historial, el alcance mira el equipo de cada mes', () async {
      // La persona 2 hoy está en Backend, pero hasta junio estuvo en Frontend.
      Future<AssistantData> data() async => _data(
        employees: [_employee('1', 'Backend'), _employee('2', 'Backend')],
        history: [
          _validity('1', 'Backend', DateTime(2020)),
          _validity('2', 'Frontend', DateTime(2020), DateTime(2026, 7)),
          _validity('2', 'Backend', DateTime(2026, 7)),
        ],
        certifications: [
          for (final month in [6, 7]) ...[
            _completion('1', month),
            _completion('2', month),
          ],
        ],
        scope: const UserScope(teamKeys: {('desarrollo', 'backend')}),
      );

      final june = await _build(_general, month: 6, loadData: data);
      final july = await _build(_general, month: 7, loadData: data);

      expect((_result(june)['global'] as Map)['colaboradores'], 1);
      expect((_result(july)['global'] as Map)['colaboradores'], 2);
    });

    test('un mes con movimientos y sin evaluables no tiene KPI', () async {
      final context = await _build(
        _general,
        loadData: () async => _data(
          employees: [
            _employee('1', 'Backend', hireDate: DateTime(2026, 8, 1)),
          ],
        ),
      );

      expect(_result(context), {
        'periodo': {'anio': 2026, 'mes': 7, 'alcance': 'mensual'},
        'tiene_datos': true,
        'disponibilidad':
            'Hay movimientos pero no colaboradores evaluables; no hay un KPI de cumplimiento para mostrar.',
      });
    });

    test('un fallo del cálculo deja el período incompleto', () async {
      // Con historial, una persona sin vigencias no se puede evaluar.
      final context = await _build(
        _general,
        loadData: () async =>
            _data(history: [_validity('1', 'Backend', DateTime(2020))]),
      );

      expect(_result(context), {
        'periodo': {'anio': 2026, 'mes': 7, 'alcance': 'mensual'},
        'tiene_datos': true,
        'disponibilidad':
            'Preparación incompleta: los bloques presentes conservan su alcance. Solo los campos ausentes no están disponibles en esta consulta; no implican ausencia de registros.',
      });
    });

    test('si no se pueden leer los datos, la consulta falla', () async {
      await expectLater(
        _build(_general, loadData: _unavailable),
        throwsStateError,
      );
    });

    test('el perfil no exige elegibilidad del período', () async {
      final context = await _build(
        '¿Cómo viene el colaborador seleccionado?',
        destination: const AssistantDestination(
          AssistantModule.people,
          employeeId: '1',
        ),
        loadData: () async => _data(
          employees: [
            _employee('1', 'Backend', hireDate: DateTime(2026, 8, 1)),
          ],
        ),
      );

      final profile = _result(context)['perfil_seleccionado'] as Map;
      expect(profile['nombre'], 'Persona 1');
      expect(profile['horas_validas'], 4.0);
    });

    test('el anual del perfil suma sus meses con datos desde el ingreso, '
        'como la pantalla', () async {
      final context = await AssistantContextBuilder().build(
        const AssistantQueryPlanner().plan(
          '¿Cómo viene el colaborador seleccionado?',
          const AssistantDestination(AssistantModule.people, employeeId: '1'),
          const PeriodFilter(scope: PeriodScope.annual, month: 9, year: 2026),
        ),
        dynamic: true,
        loadData: () async => _data(
          employees: [
            _employee('1', 'Backend', hireDate: DateTime(2026, 8, 1)),
            _employee('2', 'Frontend'),
          ],
          // July has data, but it is before the hire month.
          certifications: [_completion('1', 8), _completion('2', 7)],
        ),
      );

      final profile = _result(context)['perfil_seleccionado'] as Map;
      // Only August: 4 + 4 of Junior 1, not 12 months.
      expect(profile['horas_objetivo'], 8.0);
      expect(profile['horas_validas'], 4.0);
    });

    test('un perfil que no está en la nómina queda anotado', () async {
      final context = await _build(
        '¿Cómo viene el colaborador seleccionado?',
        destination: const AssistantDestination(
          AssistantModule.people,
          employeeId: '99',
        ),
        loadData: () async => _data(),
      );

      expect(_result(context).containsKey('perfil_seleccionado'), isFalse);
      expect(context.data['notas_alcance'], [
        'No se encontró el perfil seleccionado en la nómina disponible.',
      ]);
    });
  });

  group('Acumulado de un rango', () {
    const question = '¿Cuál es el cumplimiento acumulado de junio a julio?';

    test('un mes sin evaluables se excluye sin asignarle 0 %', () async {
      final context = await _build(
        question,
        loadData: () async => _data(
          employees: [
            _employee('1', 'Backend', hireDate: DateTime(2026, 7, 1)),
          ],
          certifications: [_completion('1', 6), _completion('1', 7)],
        ),
      );

      final accumulated = context.data['acumulado_solicitado'] as Map;
      expect(accumulated['meses'], [
        {'periodo': '2026-06', 'estado': 'sin_colaboradores_evaluables'},
        {'periodo': '2026-07', 'estado': 'evaluado'},
      ]);
      expect(accumulated['estado'], 'disponible');
      expect(accumulated['horas_validas'], 4.0);
      expect(accumulated['horas_objetivo'], 8.0);
    });

    test('un fallo de lectura no publica el total', () async {
      final context = await _build(question, loadData: _unavailable);

      expect(context.data['acumulado_solicitado'], {
        'alcance': 'global_organizacion',
        'desde': '2026-06',
        'hasta': '2026-07',
        'completo': false,
        'estado': 'incompleto',
        'meses_solicitados': 2,
        'meses_evaluados': 0,
        'meses': [
          {'periodo': '2026-06', 'estado': 'no_consultado'},
          {'periodo': '2026-07', 'estado': 'no_consultado'},
        ],
      });
      expect((context.data['desglose_mensual'] as Map)['items'], isEmpty);
    });

    test('sin meses con datos no hay total', () async {
      final context = await _build(
        '¿Cuál es el cumplimiento acumulado de enero a febrero?',
        loadData: () async => _data(),
      );

      final accumulated = context.data['acumulado_solicitado'] as Map;
      expect(accumulated['estado'], 'sin_meses_evaluables');
      expect(accumulated.containsKey('horas_validas'), isFalse);
    });
  });

  test('las consultas sin indicadores no leen datos', () async {
    for (final (question, destination, dynamic) in [
      ('¿Qué significa cumplimiento?', _dashboard, true),
      ('¿Cómo importo el archivo de nómina?', _dashboard, true),
      ('¿Cómo viene el trimestre?', _dashboard, true),
      (_general, _dashboard, false),
    ]) {
      final context = await _build(
        question,
        destination: destination,
        dynamic: dynamic,
        loadData: _unavailable,
      );
      expect(context.dynamic, dynamic, reason: question);
    }
  });
}
