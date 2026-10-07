enum RolUsuario {
  admin('Administrador', 'Administra los usuarios del sistema'),
  academia('Academia', 'Ve la información de toda la empresa'),
  area('Área', 'Ve los equipos de su área'),
  lider('Líder de equipo', 'Ve los integrantes de su equipo');

  final String label;
  final String descripcion;
  const RolUsuario(this.label, this.descripcion);

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
