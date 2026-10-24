import 'package:app_finnegans/domain/modelos/alcance_usuario.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:flutter_test/flutter_test.dart';

Empleado _empleado(
  String legajo,
  String area,
  String equipo, {
  String? mail,
  bool activo = true,
}) => Empleado(
  legajo: legajo,
  nombre: 'Nombre$legajo',
  apellido: 'Apellido',
  seniority: Seniority.junior1,
  area: area,
  mail: mail ?? 'e$legajo@finnegans.com',
  equipo: equipo,
  activo: activo,
);

/// PRODUCTOS TECNOLÓGICOS con PLATAFORMA CORE y BACKEND, y SERVICIOS con
/// IMPLEMENTACIONES.
EstructuraOrganizacional _estructura() => EstructuraOrganizacional(
  areas: [
    Area(
      id: '1',
      nombre: 'PRODUCTOS TECNOLÓGICOS',
      lideres: {'Area.Tec@finnegans.com'},
    ),
    Area(
      id: '2',
      nombre: 'SERVICIOS',
      lideres: {'area.serv@finnegans.com', 'area.tec@finnegans.com'},
    ),
  ],
  equipos: [
    Equipo(
      id: '10',
      areaId: '1',
      nombre: 'PLATAFORMA CORE',
      lideres: {'lider.uno@finnegans.com', 'lider.dos@finnegans.com'},
    ),
    Equipo(
      id: '11',
      areaId: '1',
      nombre: 'BACKEND',
      lideres: {'lider.uno@finnegans.com'},
    ),
    Equipo(id: '20', areaId: '2', nombre: 'IMPLEMENTACIONES'),
  ],
);

void main() {
  group('Clave de nómina', () {
    test('Recorta y pasa a minúsculas, igual que la base', () {
      expect(
        EstructuraOrganizacional.claveNomina('  PRODUCTOS TECNOLÓGICOS '),
        'productos tecnológicos',
      );
      expect(Area(id: '1', nombre: ' Servicios ').claveNomina, 'servicios');
    });

    test('Los emails de líderes se guardan normalizados', () {
      final area = Area(
        id: '1',
        nombre: 'X',
        lideres: {'  Ana@Finnegans.COM '},
      );
      expect(area.lideres, {'ana@finnegans.com'});
    });

    test('Áreas y equipos se buscan por el texto de la nómina', () {
      final estructura = _estructura();
      expect(estructura.areaDeNomina('servicios ')!.id, '2');
      expect(
        estructura
            .equipoDeNomina('Productos Tecnológicos', 'plataforma core')!
            .id,
        '10',
      );
      expect(estructura.equipoDeNomina('SERVICIOS', 'PLATAFORMA CORE'), isNull);
      expect(estructura.areaDeNomina('RRHH'), isNull);
    });
  });

  group('Faltantes de la nómina', () {
    test('Crea las áreas y los equipos nuevos una sola vez', () {
      final faltantes = _estructura().faltantesDeNomina([
        _empleado('1', 'RRHH', 'Selección'),
        _empleado('2', 'rrhh ', 'SELECCIÓN'),
        _empleado('3', 'RRHH', 'Liquidaciones'),
        _empleado('4', 'SERVICIOS', 'Soporte'),
        _empleado('5', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE'),
        _empleado('6', 'SERVICIOS', ''),
        _empleado('7', '', 'Huérfano'),
      ]);

      expect(faltantes.areas, ['RRHH']);
      expect(faltantes.equipos, [
        (area: 'RRHH', equipo: 'Selección'),
        (area: 'RRHH', equipo: 'Liquidaciones'),
        (area: 'SERVICIOS', equipo: 'Soporte'),
      ]);
    });

    test('Una nómina conocida no crea nada', () {
      final faltantes = _estructura().faltantesDeNomina([
        _empleado('1', 'productos tecnológicos', 'backend'),
        _empleado('2', 'SERVICIOS', 'IMPLEMENTACIONES'),
      ]);
      expect(faltantes.vacio, isTrue);
    });
  });

  group('Líderes', () {
    test('Se buscan por el texto de la nómina', () {
      final estructura = _estructura();
      expect(
        estructura.lideresDeEquipo('productos tecnológicos', 'PLATAFORMA CORE'),
        {'lider.uno@finnegans.com', 'lider.dos@finnegans.com'},
      );
      expect(estructura.lideresDeArea('PRODUCTOS TECNOLÓGICOS'), {
        'area.tec@finnegans.com',
      });
      expect(estructura.lideresDeEquipo('RRHH', 'Selección'), isEmpty);
    });

    test('Una persona puede liderar varios equipos y varias áreas', () {
      final estructura = _estructura();
      expect(
        estructura
            .equiposLideradosPor('LIDER.UNO@finnegans.com')
            .map((liderado) => liderado.equipo.nombre),
        ['BACKEND', 'PLATAFORMA CORE'],
      );
      expect(
        estructura
            .areasLideradasPor('area.tec@finnegans.com')
            .map((area) => area.nombre),
        ['PRODUCTOS TECNOLÓGICOS', 'SERVICIOS'],
      );
    });

    test('Lidera describe lo asignado según el rol', () {
      final estructura = _estructura();
      expect(
        estructura.lidera(
          rol: RolUsuario.lider,
          email: 'lider.uno@finnegans.com',
        ),
        'BACKEND, PLATAFORMA CORE',
      );
      expect(
        estructura.lidera(rol: RolUsuario.lider, email: 'nadie@finnegans.com'),
        'Sin equipos asignados',
      );
      expect(
        estructura.lidera(
          rol: RolUsuario.area,
          email: 'area.serv@finnegans.com',
        ),
        'SERVICIOS',
      );
      expect(
        estructura.lidera(rol: RolUsuario.area, email: 'nadie@finnegans.com'),
        'Sin áreas asignadas',
      );
      expect(
        estructura.lidera(rol: RolUsuario.academia, email: 'x@finnegans.com'),
        'Toda la empresa',
      );
      expect(estructura.lidera(rol: null, email: 'x@finnegans.com'), isNull);
    });

    test('La etiqueta usa el nombre de la nómina si lo conoce', () {
      expect(
        EstructuraOrganizacional.etiquetaLideres(
          {'zoe@finnegans.com', 'Ana@finnegans.com', 'externo@gmail.com'},
          {'zoe@finnegans.com': 'Zoe Paz', 'ana@finnegans.com': 'Ana Ruiz'},
        ),
        'Ana Ruiz, externo@gmail.com, Zoe Paz',
      );
    });
  });

  group('Pertenencia en la nómina', () {
    test('Empleado.porMail compara normalizado y prefiere la fila activa', () {
      final baja = _empleado(
        '1',
        'SERVICIOS',
        'SOPORTE',
        mail: 'ana@x.com',
        activo: false,
      );
      final activa = _empleado(
        '2',
        'SERVICIOS',
        'IMPLEMENTACIONES',
        mail: ' ANA@x.com',
      );
      expect(Empleado.porMail([baja, activa], 'ana@X.com'), same(activa));
      expect(Empleado.porMail([baja], 'ana@x.com'), same(baja));
      expect(Empleado.porMail([activa], 'otra@x.com'), isNull);
      expect(Empleado.porMail([activa], null), isNull);
      expect(Empleado.porMail([activa], '  '), isNull);
    });

    test('Describe equipo y área, sin equipo, baja y ausencia', () {
      expect(
        EstructuraOrganizacional.pertenencia(
          _empleado('1', 'SERVICIOS', 'IMPLEMENTACIONES'),
        ),
        'IMPLEMENTACIONES · SERVICIOS',
      );
      expect(
        EstructuraOrganizacional.pertenencia(_empleado('2', 'SERVICIOS', ' ')),
        'Sin equipo · SERVICIOS',
      );
      expect(
        EstructuraOrganizacional.pertenencia(
          _empleado('3', 'SERVICIOS', 'SOPORTE', activo: false),
        ),
        'SOPORTE · SERVICIOS (baja en la nómina)',
      );
      expect(
        EstructuraOrganizacional.pertenencia(null),
        EstructuraOrganizacional.noFiguraEnNomina,
      );
    });
  });

  group('AlcanceUsuario', () {
    final core = _empleado('1', 'PRODUCTOS TECNOLÓGICOS', 'PLATAFORMA CORE');
    final backend = _empleado('2', 'productos tecnológicos ', 'Backend');
    final sinEquipo = _empleado('3', 'PRODUCTOS TECNOLÓGICOS', '');
    final implementaciones = _empleado('4', 'SERVICIOS', 'IMPLEMENTACIONES');
    final todos = [core, backend, sinEquipo, implementaciones];

    List<String> visibles(AlcanceUsuario alcance) => [
      for (final empleado in todos)
        if (alcance.incluyeEmpleado(empleado)) empleado.legajo,
    ];

    test('Administrador y Academia ven todo, aun sin estructura', () {
      for (final rol in [RolUsuario.admin, RolUsuario.academia]) {
        final alcance = AlcanceUsuario.de(
          rol: rol,
          email: 'x@finnegans.com',
          estructura: null,
        );
        expect(alcance.esTotal, isTrue);
        expect(visibles(alcance), ['1', '2', '3', '4']);
      }
    });

    test('Un líder ve solo los equipos que lidera', () {
      final uno = AlcanceUsuario.de(
        rol: RolUsuario.lider,
        email: 'Lider.Uno@finnegans.com',
        estructura: _estructura(),
      );
      expect(visibles(uno), ['1', '2']);

      final dos = AlcanceUsuario.de(
        rol: RolUsuario.lider,
        email: 'lider.dos@finnegans.com',
        estructura: _estructura(),
      );
      expect(visibles(dos), ['1']);
    });

    test('Un usuario de área ve toda el área, sin equipo incluidos', () {
      final servicios = AlcanceUsuario.de(
        rol: RolUsuario.area,
        email: 'area.serv@finnegans.com',
        estructura: _estructura(),
      );
      expect(visibles(servicios), ['4']);

      final tec = AlcanceUsuario.de(
        rol: RolUsuario.area,
        email: 'area.tec@finnegans.com',
        estructura: _estructura(),
      );
      expect(visibles(tec), ['1', '2', '3', '4']);
    });

    test('El rol decide qué asignación cuenta', () {
      // Lidera equipos, pero con rol Área solo cuentan las áreas.
      final alcance = AlcanceUsuario.de(
        rol: RolUsuario.area,
        email: 'lider.uno@finnegans.com',
        estructura: _estructura(),
      );
      expect(alcance.sinAsignaciones, isTrue);
      expect(visibles(alcance), isEmpty);
    });

    test('Un rol desconocido o sin email no ve nada', () {
      expect(
        visibles(
          AlcanceUsuario.de(
            rol: null,
            email: 'lider.uno@finnegans.com',
            estructura: _estructura(),
          ),
        ),
        isEmpty,
      );
      expect(
        visibles(
          AlcanceUsuario.de(
            rol: RolUsuario.lider,
            email: null,
            estructura: _estructura(),
          ),
        ),
        isEmpty,
      );
    });
  });
}
