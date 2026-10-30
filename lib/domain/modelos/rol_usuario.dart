enum UserRole {
  admin('Administrador', 'Ve toda la empresa y administra usuarios y líderes'),
  academy('Academia', 'Ve toda la empresa y administra usuarios y líderes'),
  areaLead('Área', 'Ve los equipos de las áreas que lidera'),
  teamLead('Líder de equipo', 'Ve los integrantes de los equipos que lidera');

  final String label;
  final String description;
  const UserRole(this.label, this.description);

  /// Ve toda la empresa, importa archivos y entra al panel de administración.
  bool get canManage => this == admin || this == academy;

  static UserRole? fromString(String? raw) {
    if (raw == null) return null;
    final clean = _normalize(raw);
    if (clean.isEmpty) return null;
    for (final role in UserRole.values) {
      if (_normalize(role.name) == clean || _normalize(role.label) == clean) {
        return role;
      }
    }
    return null;
  }

  static String _normalize(String raw) => raw
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
