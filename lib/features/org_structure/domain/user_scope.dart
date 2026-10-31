/// Qué colaboradores puede ver el usuario de la sesión: todos, o los de las
/// áreas y los equipos indicados por su clave de nómina.
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
