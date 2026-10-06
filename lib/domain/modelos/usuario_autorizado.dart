import 'package:app_finnegans/domain/modelos/rol_usuario.dart';

enum EstadoUsuario {
  activo('Activo'),
  bloqueado('Bloqueado'),
  eliminado('Eliminado');

  final String label;
  const EstadoUsuario(this.label);
}

class UsuarioAutorizado {
  final String email;
  final String rol;
  final bool activo;
  final DateTime? ffAlta;
  final DateTime? ffBloqueo;
  final DateTime? ffEliminar;

  UsuarioAutorizado({
    required String email,
    required this.rol,
    required this.activo,
    this.ffAlta,
    this.ffBloqueo,
    this.ffEliminar,
  }) : email = email.trim().toLowerCase();

  UsuarioAutorizado.nuevo({
    required String email,
    required RolUsuario rol,
    required DateTime ahora,
  }) : this(email: email, rol: rol.name, activo: true, ffAlta: ahora);

  RolUsuario? get rolConocido => RolUsuario.fromString(rol);

  bool get esAdmin => rolConocido == RolUsuario.admin;

  EstadoUsuario get estado {
    if (ffEliminar != null) return EstadoUsuario.eliminado;
    if (ffBloqueo != null) return EstadoUsuario.bloqueado;
    return EstadoUsuario.activo;
  }

  bool get activoCalculado => ffEliminar == null && ffBloqueo == null;

  bool esMismoUsuario(String? emailSesion) =>
      emailSesion != null && emailSesion.trim().toLowerCase() == email;

  UsuarioAutorizado conRol(RolUsuario nuevoRol) => _con(rol: nuevoRol.name);

  UsuarioAutorizado bloqueado(DateTime ahora) => _con(ffBloqueo: ahora);

  UsuarioAutorizado desbloqueado() => _con(limpiarBloqueo: true);

  UsuarioAutorizado eliminado(DateTime ahora) => _con(ffEliminar: ahora);

  UsuarioAutorizado restaurado() => _con(limpiarEliminacion: true);

  UsuarioAutorizado _con({
    String? rol,
    DateTime? ffBloqueo,
    DateTime? ffEliminar,
    bool limpiarBloqueo = false,
    bool limpiarEliminacion = false,
  }) {
    final bloqueo = limpiarBloqueo ? null : (ffBloqueo ?? this.ffBloqueo);
    final eliminacion = limpiarEliminacion
        ? null
        : (ffEliminar ?? this.ffEliminar);
    return UsuarioAutorizado(
      email: email,
      rol: rol ?? this.rol,
      activo: eliminacion == null && bloqueo == null,
      ffAlta: ffAlta,
      ffBloqueo: bloqueo,
      ffEliminar: eliminacion,
    );
  }
}
