/// Which employees the session user can see: all of them, or those of the
/// areas and teams given by their payroll key.
class UserScope {
  final bool isTotal;
  final Set<String> areaKeys;
  final Set<(String, String)> teamKeys;

  const UserScope({
    this.isTotal = false,
    this.areaKeys = const {},
    this.teamKeys = const {},
  });

  const UserScope.total() : this(isTotal: true);

  const UserScope.none() : this();
}
