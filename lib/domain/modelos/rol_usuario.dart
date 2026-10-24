enum RolUsuario {
  admin('Administrador', 'Ve toda la empresa y administra usuarios y líderes'),
  academia('Academia', 'Ve toda la empresa y administra usuarios y líderes'),
  area('Área', 'Ve los equipos de las áreas que lidera'),
  lider('Líder de equipo', 'Ve los integrantes de los equipos que lidera');

  final String label;
  final String descripcion;
  const RolUsuario(this.label, this.descripcion);

  /// Ve toda la empresa, importa archivos y entra al panel de administración.
  bool get esGestor => this == admin || this == academia;

  static RolUsuario? fromString(String? raw) {
    if (raw == null) return null;
    final limpio = _normalizar(raw);
    if (limpio.isEmpty) return null;
    for (final rol in RolUsuario.values) {
      if (_normalizar(rol.name) == limpio || _normalizar(rol.label) == limpio) {
        return rol;
      }
    }
    return null;
  }

  static String _normalizar(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
