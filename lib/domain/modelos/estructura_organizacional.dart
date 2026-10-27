import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';

/// Área de `public.areas`. Sale de la importación de nómina: su nombre es el
/// Sector tal como vino en el Excel, y no se edita desde la app.
class Area {
  final String id;
  final String nombre;
  final Set<String> lideres;

  Area({required this.id, required this.nombre, Set<String> lideres = const {}})
    : lideres = {
        for (final email in lideres)
          EstructuraOrganizacional.normalizarEmail(email),
      };

  String get claveNomina => EstructuraOrganizacional.claveNomina(nombre);
}

/// Equipo de `public.equipos`. Pertenece a un área y, como ella, sale de la
/// importación de nómina.
class Equipo {
  final String id;
  final String areaId;
  final String nombre;
  final Set<String> lideres;

  Equipo({
    required this.id,
    required this.areaId,
    required this.nombre,
    Set<String> lideres = const {},
  }) : lideres = {
         for (final email in lideres)
           EstructuraOrganizacional.normalizarEmail(email),
       };

  String get claveNomina => EstructuraOrganizacional.claveNomina(nombre);
}

/// Áreas y equipos que trae una nómina y todavía no tienen fila.
class FaltantesNomina {
  final List<String> areas;
  final List<({String area, String equipo})> equipos;

  const FaltantesNomina({this.areas = const [], this.equipos = const []});

  bool get vacio => areas.isEmpty && equipos.isEmpty;
}

/// Áreas, equipos y líderes, con las reglas que los cruzan con la nómina.
///
/// El empleado se une con su área y su equipo por la clave de nómina (el
/// texto del Excel recortado y en minúsculas), así "RRHH" y "rrhh " son la
/// misma área.
class EstructuraOrganizacional {
  final List<Area> areas;
  final List<Equipo> equipos;

  final Map<String, Area> _areasPorClave;
  final Map<(String, String), Equipo> _equiposPorClave;

  EstructuraOrganizacional({required this.areas, required this.equipos})
    : _areasPorClave = {for (final area in areas) area.claveNomina: area},
      _equiposPorClave = {
        for (final equipo in equipos)
          (equipo.areaId, equipo.claveNomina): equipo,
      };

  /// Misma regla que `public.clave_nomina()` en la base.
  static String claveNomina(String texto) => texto.trim().toLowerCase();

  static String normalizarEmail(String email) => email.trim().toLowerCase();

  static int _porNombre(String a, String b) =>
      claveNomina(a).compareTo(claveNomina(b));

  /// Áreas ordenadas por nombre.
  List<Area> get areasOrdenadas =>
      [...areas]..sort((a, b) => _porNombre(a.nombre, b.nombre));

  /// Equipos de un área, ordenados por nombre.
  List<Equipo> equiposDe(String areaId) =>
      equipos.where((equipo) => equipo.areaId == areaId).toList()
        ..sort((a, b) => _porNombre(a.nombre, b.nombre));

  /// Área por el Sector de la nómina.
  Area? areaDeNomina(String sector) => _areasPorClave[claveNomina(sector)];

  /// Equipo por el Sector y el Equipo de la nómina.
  Equipo? equipoDeNomina(String sector, String equipo) {
    final area = areaDeNomina(sector);
    if (area == null) return null;
    return _equiposPorClave[(area.id, claveNomina(equipo))];
  }

  Set<String> lideresDeArea(String sector) =>
      areaDeNomina(sector)?.lideres ?? const {};

  Set<String> lideresDeEquipo(String sector, String equipo) =>
      equipoDeNomina(sector, equipo)?.lideres ?? const {};

  List<Area> areasLideradasPor(String email) {
    final normalizado = normalizarEmail(email);
    return areasOrdenadas
        .where((area) => area.lideres.contains(normalizado))
        .toList();
  }

  /// Equipos que lidera ese email, ordenados por área y por nombre.
  List<({Area area, Equipo equipo})> equiposLideradosPor(String email) {
    final normalizado = normalizarEmail(email);
    return [
      for (final area in areasOrdenadas)
        for (final equipo in equiposDe(area.id))
          if (equipo.lideres.contains(normalizado))
            (area: area, equipo: equipo),
    ];
  }

  /// Lo que la importación de [empleados] tiene que crear: las áreas y los
  /// equipos cuya clave todavía no existe, con el texto del primer empleado
  /// que los trae.
  FaltantesNomina faltantesDeNomina(Iterable<Empleado> empleados) {
    final areasNuevas = <String, String>{};
    final equiposNuevos = <(String, String), ({String area, String equipo})>{};

    for (final empleado in empleados) {
      final sector = empleado.area.trim();
      final claveArea = claveNomina(sector);
      if (claveArea.isEmpty) continue;
      final area = _areasPorClave[claveArea];
      if (area == null) areasNuevas.putIfAbsent(claveArea, () => sector);

      final equipo = empleado.equipo.trim();
      final claveEquipo = claveNomina(equipo);
      if (claveEquipo.isEmpty) continue;
      if (area != null &&
          _equiposPorClave.containsKey((area.id, claveEquipo))) {
        continue;
      }
      equiposNuevos.putIfAbsent((
        claveArea,
        claveEquipo,
      ), () => (area: area?.nombre ?? areasNuevas[claveArea]!, equipo: equipo));
    }

    return FaltantesNomina(
      areas: areasNuevas.values.toList(),
      equipos: equiposNuevos.values.toList(),
    );
  }

  /// Lo que lidera un usuario según su rol: toda la empresa, o los nombres
  /// de las áreas o los equipos asignados. `null` para un rol desconocido.
  String? lidera({required RolUsuario? rol, required String email}) {
    switch (rol) {
      case null:
        return null;
      case RolUsuario.admin || RolUsuario.academia:
        return 'Toda la empresa';
      case RolUsuario.area:
        final areas = areasLideradasPor(email);
        return areas.isEmpty
            ? 'Sin áreas asignadas'
            : areas.map((area) => area.nombre).join(', ');
      case RolUsuario.lider:
        final equipos = equiposLideradosPor(email);
        return equipos.isEmpty
            ? 'Sin equipos asignados'
            : equipos.map((liderado) => liderado.equipo.nombre).join(', ');
    }
  }

  static const noFiguraEnNomina = 'No figura en la nómina';

  /// Equipo y área a los que pertenece alguien según su fila de la nómina,
  /// para mostrar junto a lo que lidera (que es una asignación aparte).
  static String pertenencia(Empleado? empleado) {
    if (empleado == null) return noFiguraEnNomina;
    final equipo = empleado.equipo.trim();
    final area = empleado.area.trim();
    final texto = [
      equipo.isEmpty ? 'Sin equipo' : equipo,
      if (area.isNotEmpty) area,
    ].join(' · ');
    return empleado.activo ? texto : '$texto (baja en la nómina)';
  }

  /// Líderes para mostrar: el nombre de la nómina si el email coincide con el
  /// de algún empleado visible, y si no el email.
  static String etiquetaLideres(
    Iterable<String> emails,
    Map<String, String> nombrePorEmail,
  ) {
    final nombres = [
      for (final email in emails)
        nombrePorEmail[normalizarEmail(email)] ?? normalizarEmail(email),
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return nombres.join(', ');
  }
}
