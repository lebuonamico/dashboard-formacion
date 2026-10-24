import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';

/// Qué colaboradores puede ver el usuario de la sesión.
///
/// Es el mismo criterio que `public.empleado_visible()` en la base, que es la
/// que manda: acá sirve para que la app no dependa de que el RLS esté
/// encendido y para poder probarlo sin Supabase. Compara por clave de nómina
/// ([EstructuraOrganizacional.claveNomina]), igual que la base.
class AlcanceUsuario {
  final bool esTotal;
  final Set<String> _areas;
  final Set<(String, String)> _equipos;

  const AlcanceUsuario.total()
    : esTotal = true,
      _areas = const {},
      _equipos = const {};

  const AlcanceUsuario.ninguno()
    : esTotal = false,
      _areas = const {},
      _equipos = const {};

  const AlcanceUsuario._(this._areas, this._equipos) : esTotal = false;

  /// Administrador y Academia ven todo. `area` ve las áreas que lidera y
  /// `lider` los equipos que lidera. Cualquier otro rol, nada.
  factory AlcanceUsuario.de({
    required RolUsuario? rol,
    required String? email,
    required EstructuraOrganizacional? estructura,
  }) {
    if (rol != null && rol.esGestor) return const AlcanceUsuario.total();
    if (email == null || estructura == null) {
      return const AlcanceUsuario.ninguno();
    }
    switch (rol) {
      case RolUsuario.area:
        return AlcanceUsuario._({
          for (final area in estructura.areasLideradasPor(email))
            area.claveNomina,
        }, const {});
      case RolUsuario.lider:
        return AlcanceUsuario._(const {}, {
          for (final liderado in estructura.equiposLideradosPor(email))
            (liderado.area.claveNomina, liderado.equipo.claveNomina),
        });
      default:
        return const AlcanceUsuario.ninguno();
    }
  }

  /// Si ve a un empleado con ese Sector y ese Equipo de la nómina.
  bool incluye(String sector, String equipo) {
    if (esTotal) return true;
    final area = EstructuraOrganizacional.claveNomina(sector);
    return _areas.contains(area) ||
        _equipos.contains((area, EstructuraOrganizacional.claveNomina(equipo)));
  }

  bool incluyeEmpleado(Empleado empleado) =>
      incluye(empleado.area, empleado.equipo);
}
