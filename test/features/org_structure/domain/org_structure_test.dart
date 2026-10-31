import 'package:app_finnegans/features/org_structure/domain/org_structure_service.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/org_structure/presentation/org_structure_labels.dart';

Employee _employee(
  String employeeId,
  String area,
  String team, {
  String? email,
  bool active = true,
}) => Employee(
  employeeId: employeeId,
  firstName: 'Nombre$employeeId',
  lastName: 'Apellido',
  seniority: Seniority.junior1,
  area: area,
  email: email ?? 'e$employeeId@finnegans.com',
  team: team,
  isActive: active,
);

const _service = OrgStructureService();
const _scopes = UserScopeService();

/// PRODUCTOS TECNOLÓGICOS con PLATAFORMA CORE y BACKEND, y SERVICIOS con
/// IMPLEMENTACIONES. Los emails llegan normalizados, como los da el
/// repositorio.
OrgStructure _structure() => const OrgStructure(
  areas: [
    Area(
      id: '1',
      name: 'PRODUCTOS TECNOLÓGICOS',
      leaders: {'area.tec@finnegans.com'},
    ),
    Area(
      id: '2',
      name: 'SERVICIOS',
      leaders: {'area.serv@finnegans.com', 'area.tec@finnegans.com'},
    ),
  ],
  teams: [
    Team(
      id: '10',
      areaId: '1',
      name: 'PLATAFORMA CORE',
      leaders: {'lider.uno@finnegans.com', 'lider.dos@finnegans.com'},
    ),
    Team(
      id: '11',
      areaId: '1',
      name: 'BACKEND',
      leaders: {'lider.uno@finnegans.com'},
    ),
    Team(id: '20', areaId: '2', name: 'IMPLEMENTACIONES'),
  ],
);

void main() {
  group('Colaboradores por área y equipo', () {
    test('Cuenta solo los activos y une los textos por clave de nómina', () {
      final headcount = _service.activeHeadcount([
        _employee('1', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'),
        _employee('2', ' productos tecnológicos', 'plataforma core '),
        _employee('3', 'PRODUCTOS TECNOLÓGICOS', 'BACKEND', active: false),
        _employee('4', 'SERVICIOS', ''),
      ]);
      final structure = _structure();
      final tec = structure.areas.first;
      final services = structure.areas.last;

      expect(_service.areaHeadcount(headcount, tec), 2);
      expect(_service.areaHeadcount(headcount, services), 1);
      expect(_service.teamHeadcount(headcount, tec, structure.teams[0]), 2);
      expect(_service.teamHeadcount(headcount, tec, structure.teams[1]), 0);
      expect(
        _service.teamHeadcount(headcount, services, structure.teams[2]),
        0,
      );
    });
  });

  group('Búsqueda de áreas', () {
    test('Sin texto devuelve todas, ordenadas', () {
      expect(
        _service.areasMatching(_structure(), '  ').map((area) => area.id),
        ['1', '2'],
      );
    });

    test('Coincide por el nombre del área o de uno de sus equipos', () {
      expect(
        _service.areasMatching(_structure(), 'servi').map((area) => area.id),
        ['2'],
      );
      expect(
        _service.areasMatching(_structure(), 'Backend').map((area) => area.id),
        ['1'],
      );
      expect(_service.areasMatching(_structure(), 'ventas'), isEmpty);
    });
  });

  group('Clave de nómina', () {
    test('Recorta y pasa a minúsculas, igual que la base', () {
      const structure = OrgStructure(
        areas: [Area(id: '1', name: ' Servicios ')],
        teams: [],
      );
      expect(
        _service.payrollArea(_structure(), '  PRODUCTOS TECNOLÓGICOS ')!.id,
        '1',
      );
      expect(_service.payrollArea(structure, 'SERVICIOS')!.id, '1');
    });

    test('Áreas y equipos se buscan por el texto de la nómina', () {
      final structure = _structure();
      expect(_service.payrollArea(structure, 'servicios ')!.id, '2');
      expect(
        _service
            .payrollTeam(
              structure,
              'Productos Tecnológicos',
              'plataforma core',
            )!
            .id,
        '10',
      );
      expect(
        _service.payrollTeam(structure, 'SERVICIOS', 'PLATAFORMA CORE'),
        isNull,
      );
      expect(_service.payrollArea(structure, 'RRHH'), isNull);
    });
  });

  group('Faltantes de la nómina', () {
    test('Crea las áreas y los equipos nuevos una sola vez', () {
      final missing = _service.missingFromPayroll(_structure(), [
        _employee('1', 'RRHH', 'Selección'),
        _employee('2', 'rrhh ', 'SELECCIÓN'),
        _employee('3', 'RRHH', 'Liquidaciones'),
        _employee('4', 'SERVICIOS', 'Soporte'),
        _employee('5', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'),
        _employee('6', 'SERVICIOS', ''),
        _employee('7', '', 'Huérfano'),
      ]);

      expect(missing.areas, ['RRHH']);
      expect(missing.teams, [
        (area: 'RRHH', team: 'Selección'),
        (area: 'RRHH', team: 'Liquidaciones'),
        (area: 'SERVICIOS', team: 'Soporte'),
      ]);
    });

    test('Una nómina conocida no crea nada', () {
      final missing = _service.missingFromPayroll(_structure(), [
        _employee('1', 'productos tecnológicos', 'backend'),
        _employee('2', 'SERVICIOS', 'IMPLEMENTACIONES'),
      ]);
      expect(_service.isEmpty(missing), isTrue);
    });
  });

  group('Líderes', () {
    test('Se buscan por el texto de la nómina', () {
      final structure = _structure();
      expect(
        _service.teamLeaders(
          structure,
          'productos tecnológicos',
          'PLATAFORMA CORE',
        ),
        {'lider.uno@finnegans.com', 'lider.dos@finnegans.com'},
      );
      expect(_service.areaLeaders(structure, 'PRODUCTOS TECNOLÓGICOS'), {
        'area.tec@finnegans.com',
      });
      expect(_service.teamLeaders(structure, 'RRHH', 'Selección'), isEmpty);
    });

    test('Una persona puede liderar varios equipos y varias áreas', () {
      final structure = _structure();
      expect(
        _service
            .teamsLedBy(structure, 'LIDER.UNO@finnegans.com')
            .map((led) => led.team.name),
        ['BACKEND', 'PLATAFORMA CORE'],
      );
      expect(
        _service
            .ledAreasBy(structure, 'area.tec@finnegans.com')
            .map((area) => area.name),
        ['PRODUCTOS TECNOLÓGICOS', 'SERVICIOS'],
      );
    });

    test('Lidera describe lo asignado según el rol', () {
      final structure = _structure();
      expect(
        structure.leads(
          role: UserRole.teamLead,
          email: 'lider.uno@finnegans.com',
        ),
        'BACKEND, PLATAFORMA CORE',
      );
      expect(
        structure.leads(role: UserRole.teamLead, email: 'nadie@finnegans.com'),
        'Sin equipos asignados',
      );
      expect(
        structure.leads(
          role: UserRole.areaLead,
          email: 'area.serv@finnegans.com',
        ),
        'SERVICIOS',
      );
      expect(
        structure.leads(role: UserRole.areaLead, email: 'nadie@finnegans.com'),
        'Sin áreas asignadas',
      );
      expect(
        structure.leads(role: UserRole.academy, email: 'x@finnegans.com'),
        'Toda la empresa',
      );
      expect(structure.leads(role: null, email: 'x@finnegans.com'), isNull);
    });

    test('La etiqueta usa el nombre de la nómina si lo conoce', () {
      expect(
        OrgStructureLabels.leadersLabel(
          {'zoe@finnegans.com', 'Ana@finnegans.com', 'externo@gmail.com'},
          {'zoe@finnegans.com': 'Zoe Paz', 'ana@finnegans.com': 'Ana Ruiz'},
        ),
        'Ana Ruiz, externo@gmail.com, Zoe Paz',
      );
    });
  });

  group('Pertenencia en la nómina', () {
    test('Empleado.porMail compara normalizado y prefiere la fila activa', () {
      final removal = _employee(
        '1',
        'SERVICIOS',
        'SOPORTE',
        email: 'ana@x.com',
        active: false,
      );
      final active = _employee(
        '2',
        'SERVICIOS',
        'IMPLEMENTACIONES',
        email: ' ANA@x.com',
      );
      expect(
        const EmployeeLookupService().findByEmail([
          removal,
          active,
        ], 'ana@X.com'),
        same(active),
      );
      expect(
        const EmployeeLookupService().findByEmail([removal], 'ana@x.com'),
        same(removal),
      );
      expect(
        const EmployeeLookupService().findByEmail([active], 'otra@x.com'),
        isNull,
      );
      expect(const EmployeeLookupService().findByEmail([active], null), isNull);
      expect(const EmployeeLookupService().findByEmail([active], '  '), isNull);
    });

    test('Describe equipo y área, sin equipo, baja y ausencia', () {
      expect(
        OrgStructureLabels.membership(
          _employee('1', 'SERVICIOS', 'IMPLEMENTACIONES'),
        ),
        'IMPLEMENTACIONES · SERVICIOS',
      );
      expect(
        OrgStructureLabels.membership(_employee('2', 'SERVICIOS', ' ')),
        'Sin equipo · SERVICIOS',
      );
      expect(
        OrgStructureLabels.membership(
          _employee('3', 'SERVICIOS', 'SOPORTE', active: false),
        ),
        'SOPORTE · SERVICIOS (baja en la nómina)',
      );
      expect(
        OrgStructureLabels.membership(null),
        OrgStructureLabels.notInPayroll,
      );
    });
  });

  group('AlcanceUsuario', () {
    final core = _employee('1', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE');
    final backend = _employee('2', 'productos tecnológicos ', 'Backend');
    final noTeam = _employee('3', 'PRODUCTOS TECNOLÓGICOS', '');
    final implementations = _employee('4', 'SERVICIOS', 'IMPLEMENTACIONES');
    final all = [core, backend, noTeam, implementations];

    List<String> visible(UserScope scope) => [
      for (final employee in all)
        if (_scopes.includesEmployee(scope, employee)) employee.employeeId,
    ];

    test('Administrador y Academia ven todo, aun sin estructura', () {
      for (final role in [UserRole.admin, UserRole.academy]) {
        final scope = _scopes.scopeFor(
          role: role,
          email: 'x@finnegans.com',
          structure: null,
        );
        expect(scope.isTotal, isTrue);
        expect(visible(scope), ['1', '2', '3', '4']);
      }
    });

    test('Un líder ve solo los equipos que lidera', () {
      final one = _scopes.scopeFor(
        role: UserRole.teamLead,
        email: 'Lider.Uno@finnegans.com',
        structure: _structure(),
      );
      expect(visible(one), ['1', '2']);

      final two = _scopes.scopeFor(
        role: UserRole.teamLead,
        email: 'lider.dos@finnegans.com',
        structure: _structure(),
      );
      expect(visible(two), ['1']);
    });

    test('Un usuario de área ve toda el área, sin equipo incluidos', () {
      final services = _scopes.scopeFor(
        role: UserRole.areaLead,
        email: 'area.serv@finnegans.com',
        structure: _structure(),
      );
      expect(visible(services), ['4']);

      final tech = _scopes.scopeFor(
        role: UserRole.areaLead,
        email: 'area.tec@finnegans.com',
        structure: _structure(),
      );
      expect(visible(tech), ['1', '2', '3', '4']);
    });

    test('El rol decide qué asignación cuenta', () {
      // Lidera equipos, pero con rol Área solo cuentan las áreas.
      final scope = _scopes.scopeFor(
        role: UserRole.areaLead,
        email: 'lider.uno@finnegans.com',
        structure: _structure(),
      );
      expect(visible(scope), isEmpty);
    });

    test('Un rol desconocido o sin email no ve nada', () {
      expect(
        visible(
          _scopes.scopeFor(
            role: null,
            email: 'lider.uno@finnegans.com',
            structure: _structure(),
          ),
        ),
        isEmpty,
      );
      expect(
        visible(
          _scopes.scopeFor(
            role: UserRole.teamLead,
            email: null,
            structure: _structure(),
          ),
        ),
        isEmpty,
      );
    });
  });
}
