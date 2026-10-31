enum UserRole {
  admin,
  academy,
  areaLead,
  teamLead;

  /// Ve toda la empresa, importa archivos y entra al panel de administración.
  bool get canManage => this == admin || this == academy;
}
