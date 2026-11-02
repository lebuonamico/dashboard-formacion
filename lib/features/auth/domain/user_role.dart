enum UserRole {
  admin,
  academy,
  areaLead,
  teamLead;

  /// Sees the whole company, imports files and enters the admin panel.
  bool get canManage => this == admin || this == academy;
}
