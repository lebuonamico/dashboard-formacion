import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';

/// Columnas por las que se pueden ordenar las tablas de integrantes.
enum MemberSort { employeeId, employee, team, seniority, hours, compliance }

/// Columna activa y sentido del orden de una tabla de integrantes.
class MemberSortState {
  final MemberSort? column;
  final bool ascending;

  const MemberSortState({this.column, this.ascending = true});

  /// Primer click en una columna: ascendente; click en la misma: invierte.
  MemberSortState toggle(MemberSort newValue) => MemberSortState(
    column: newValue,
    ascending: column == newValue ? !ascending : true,
  );

  /// Copia ordenada; sin columna activa devuelve el orden original.
  List<EmployeeCompliance> apply(List<EmployeeCompliance> members) {
    final current = column;
    if (current == null) return members;
    final sorted = [...members];
    sorted.sort((a, b) {
      final result = _compare(current, a, b);
      // A igual valor, por nombre para que el orden sea estable.
      final tiebreak = result != 0
          ? result
          : a.employee.fullName.toLowerCase().compareTo(
              b.employee.fullName.toLowerCase(),
            );
      return ascending ? tiebreak : -tiebreak;
    });
    return sorted;
  }

  static int _compare(
    MemberSort column,
    EmployeeCompliance a,
    EmployeeCompliance b,
  ) => switch (column) {
    MemberSort.employeeId => _compareEmployeeId(
      a.employee.employeeId,
      b.employee.employeeId,
    ),
    MemberSort.employee => a.employee.fullName.toLowerCase().compareTo(
      b.employee.fullName.toLowerCase(),
    ),
    MemberSort.team => a.employee.team.trim().toLowerCase().compareTo(
      b.employee.team.trim().toLowerCase(),
    ),
    MemberSort.seniority => a.employee.seniority.index.compareTo(
      b.employee.seniority.index,
    ),
    MemberSort.hours => a.totalCreditedHours.compareTo(b.totalCreditedHours),
    MemberSort.compliance => a.totalPercentage.compareTo(b.totalPercentage),
  };

  /// Legajos numéricos por valor ("9" antes que "10"); el resto como texto.
  static int _compareEmployeeId(String a, String b) {
    final numberA = int.tryParse(a.trim());
    final numberB = int.tryParse(b.trim());
    if (numberA != null && numberB != null) return numberA.compareTo(numberB);
    return a.compareTo(b);
  }
}
