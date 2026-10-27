import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/domain/modelos/alcance_usuario.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estructura_organizacional.dart';
import 'package:app_finnegans/domain/modelos/rol_usuario.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/core_providers.dart';
import 'package:app_finnegans/presentation/providers/empleados_providers.dart';

/// Identidad de la sesión que define qué datos se leen.
///
/// Los providers de datos la miran para volver a consultar cuando entra otro
/// usuario en la misma pestaña: con RLS, cada usuario recibe filas distintas.
/// Mira solo estos tres campos, así no se recalcula en cada
/// `notifyListeners` de [AuthController] (por ejemplo, al validar).
final sesionDatosProvider =
    Provider<({bool habilitada, String? email, String? rol})>(
      (ref) => ref.watch(
        authControllerProvider.select(
          (auth) =>
              (habilitada: auth.enabled, email: auth.email, rol: auth.rol),
        ),
      ),
    );

/// Áreas, equipos y líderes. `null` en modo local, donde no hay sesión.
final estructuraProvider = FutureProvider<EstructuraOrganizacional?>((
  ref,
) async {
  if (!ref.watch(sesionDatosProvider).habilitada) return null;
  final repositorio = ref.watch(estructuraRepositoryProvider);
  if (repositorio == null) return null;
  return repositorio.getEstructura();
});

/// Qué colaboradores ve el usuario de la sesión. En modo local no hay roles
/// y se ve todo.
final alcanceUsuarioProvider = FutureProvider<AlcanceUsuario>((ref) async {
  final sesion = ref.watch(sesionDatosProvider);
  if (!sesion.habilitada) return const AlcanceUsuario.total();
  final rol = RolUsuario.fromString(sesion.rol);
  if (rol != null && rol.esGestor) return const AlcanceUsuario.total();
  final estructura = await ref.watch(estructuraProvider.future);
  return AlcanceUsuario.de(
    rol: rol,
    email: sesion.email,
    estructura: estructura,
  );
});

/// Fila de la nómina del usuario de la sesión, buscada por su email: el área
/// y el equipo a los que pertenece. Usa la nómina sin filtrar y no
/// [empleadosProvider], porque un líder puede no estar en lo que lidera (el
/// RLS le deja leer su propia fila). `null` en modo local o si no figura.
final empleadoDeSesionProvider = FutureProvider<Empleado?>((ref) async {
  final sesion = ref.watch(sesionDatosProvider);
  if (!sesion.habilitada || sesion.email == null) return null;
  final empleados = await ref.watch(nominaProvider.future);
  return Empleado.porMail(empleados, sesion.email);
});

/// Etiquetas de líderes para las tarjetas de equipos y áreas.
class EtiquetasLideres {
  final EstructuraOrganizacional _estructura;
  final Map<String, String> _nombrePorEmail;

  EtiquetasLideres(this._estructura, this._nombrePorEmail);

  /// `null` si el equipo no tiene líderes asignados.
  String? deEquipo(String area, String equipo) =>
      _etiqueta(_estructura.lideresDeEquipo(area, equipo));

  String? deArea(String area) => _etiqueta(_estructura.lideresDeArea(area));

  String? _etiqueta(Set<String> emails) => emails.isEmpty
      ? null
      : EstructuraOrganizacional.etiquetaLideres(emails, _nombrePorEmail);
}

/// `null` en modo local, donde no hay líderes asignados.
final etiquetasLideresProvider = FutureProvider<EtiquetasLideres?>((ref) async {
  final estructura = await ref.watch(estructuraProvider.future);
  if (estructura == null) return null;
  final empleados = await ref.watch(empleadosProvider.future);
  return EtiquetasLideres(estructura, {
    for (final empleado in empleados)
      if (empleado.mail.trim().isNotEmpty)
        EstructuraOrganizacional.normalizarEmail(empleado.mail):
            empleado.nombreCompleto,
  });
});
