import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// PRODUCTOS TECNOLÓGICOS con PLATAFORMA CORE y BACKEND, y SERVICIOS con
/// IMPLEMENTACIONES.
OrgStructure _structure() => OrgStructure(
  areas: [
    Area(
      id: '1',
      name: 'PRODUCTOS TECNOLÓGICOS',
      leaders: {'Area.Tec@finnegans.com'},
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
  group('Clave de nómina', () {
    test('Recorta y pasa a minúsculas, igual que la base', () {
      expect(
        OrgStructure.payrollKey('  PRODUCTOS TECNOLÓGICOS '),
        'productos tecnológicos',
      );
      expect(Area(id: '1', name: ' Servicios ').payrollKey, 'servicios');
    });

    test('Los emails de líderes se guardan normalizados', () {
      final area = Area(id: '1', name: 'X', leaders: {'  Ana@Finnegans.COM '});
      expect(area.leaders, {'ana@finnegans.com'});
    });

    test('Áreas y equipos se buscan por el texto de la nómina', () {
      final structure = _structure();
      expect(structure.payrollArea('servicios ')!.id, '2');
      expect(
        structure.payrollTeam('Productos Tecnológicos', 'plataforma core')!.id,
        '10',
      );
      expect(structure.payrollTeam('SERVICIOS', 'PLATAFORMA CORE'), isNull);
      expect(structure.payrollArea('RRHH'), isNull);
    });
  });

  group('Faltantes de la nómina', () {
    test('Crea las áreas y los equipos nuevos una sola vez', () {
      final missing = _structure().missingFromPayroll([
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
      final missing = _structure().missingFromPayroll([
        _employee('1', 'productos tecnológicos', 'backend'),
        _employee('2', 'SERVICIOS', 'IMPLEMENTACIONES'),
      ]);
      expect(missing.empty, isTrue);
    });
  });

  group('Líderes', () {
    test('Se buscan por el texto de la nómina', () {
      final structure = _structure();
      expect(
        structure.teamLeaders('productos tecnológicos', 'PLATAFORMA CORE'),
        {'lider.uno@finnegans.com', 'lider.dos@finnegans.com'},
      );
      expect(structure.areaLeaders('PRODUCTOS TECNOLÓGICOS'), {
        'area.tec@finnegans.com',
      });
      expect(structure.teamLeaders('RRHH', 'Selección'), isEmpty);
    });

    test('Una persona puede liderar varios equipos y varias áreas', () {
      final structure = _structure();
      expect(
        structure
            .teamsLedBy('LIDER.UNO@finnegans.com')
            .map((led) => led.team.name),
        ['BACKEND', 'PLATAFORMA CORE'],
      );
      expect(
        structure.ledAreasBy('area.tec@finnegans.com').map((area) => area.name),
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
        OrgStructure.leadersLabel(
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
      expect(Employee.byEmail([removal, active], 'ana@X.com'), same(active));
      expect(Employee.byEmail([removal], 'ana@x.com'), same(removal));
      expect(Employee.byEmail([active], 'otra@x.com'), isNull);
      expect(Employee.byEmail([active], null), isNull);
      expect(Employee.byEmail([active], '  '), isNull);
    });

    test('Describe equipo y área, sin equipo, baja y ausencia', () {
      expect(
        OrgStructure.membership(
          _employee('1', 'SERVICIOS', 'IMPLEMENTACIONES'),
        ),
        'IMPLEMENTACIONES · SERVICIOS',
      );
      expect(
        OrgStructure.membership(_employee('2', 'SERVICIOS', ' ')),
        'Sin equipo · SERVICIOS',
      );
      expect(
        OrgStructure.membership(
          _employee('3', 'SERVICIOS', 'SOPORTE', active: false),
        ),
        'SOPORTE · SERVICIOS (baja en la nómina)',
      );
      expect(OrgStructure.membership(null), OrgStructure.notInPayroll);
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
        if (scope.includesEmployee(employee)) employee.employeeId,
    ];

    test('Administrador y Academia ven todo, aun sin estructura', () {
      for (final role in [UserRole.admin, UserRole.academy]) {
        final scope = UserScope.of(
          role: role,
          email: 'x@finnegans.com',
          structure: null,
        );
        expect(scope.isTotal, isTrue);
        expect(visible(scope), ['1', '2', '3', '4']);
      }
    });

    test('Un líder ve solo los equipos que lidera', () {
      final one = UserScope.of(
        role: UserRole.teamLead,
        email: 'Lider.Uno@finnegans.com',
        structure: _structure(),
      );
      expect(visible(one), ['1', '2']);

      final two = UserScope.of(
        role: UserRole.teamLead,
        email: 'lider.dos@finnegans.com',
        structure: _structure(),
      );
      expect(visible(two), ['1']);
    });

    test('Un usuario de área ve toda el área, sin equipo incluidos', () {
      final services = UserScope.of(
        role: UserRole.areaLead,
        email: 'area.serv@finnegans.com',
        structure: _structure(),
      );
      expect(visible(services), ['4']);

      final tech = UserScope.of(
        role: UserRole.areaLead,
        email: 'area.tec@finnegans.com',
        structure: _structure(),
      );
      expect(visible(tech), ['1', '2', '3', '4']);
    });

    test('El rol decide qué asignación cuenta', () {
      // Lidera equipos, pero con rol Área solo cuentan las áreas.
      final scope = UserScope.of(
        role: UserRole.areaLead,
        email: 'lider.uno@finnegans.com',
        structure: _structure(),
      );
      expect(visible(scope), isEmpty);
    });

    test('Un rol desconocido o sin email no ve nada', () {
      expect(
        visible(
          UserScope.of(
            role: null,
            email: 'lider.uno@finnegans.com',
            structure: _structure(),
          ),
        ),
        isEmpty,
      );
      expect(
        visible(
          UserScope.of(
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
