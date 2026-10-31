import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';

enum MemberSort { employeeId, employee, team, seniority, hours, compliance }

/// Sorted column of a members table; without a column, the original order.
class MemberOrder {
  final MemberSort? column;
  final bool ascending;

  const MemberOrder({this.column, this.ascending = true});

  MemberOrder copyWith({MemberSort? column, bool? ascending}) => MemberOrder(
    column: column ?? this.column,
    ascending: ascending ?? this.ascending,
  );
}

class MemberOrderService {
  final EmployeeLookupService lookup;

  const MemberOrderService({this.lookup = const EmployeeLookupService()});

  /// A sorted copy. Ties are broken by name so the order is stable.
  List<EmployeeCompliance> sort(
    List<EmployeeCompliance> members,
    MemberOrder order,
  ) {
    final column = order.column;
    if (column == null) return members;
    return [...members]..sort((a, b) {
      final result = _compare(column, a, b);
      final tiebreak = result != 0 ? result : _name(a).compareTo(_name(b));
      return order.ascending ? tiebreak : -tiebreak;
    });
  }

  String _name(EmployeeCompliance member) =>
      lookup.fullName(member.employee).toLowerCase();

  int _compare(MemberSort column, EmployeeCompliance a, EmployeeCompliance b) =>
      switch (column) {
        MemberSort.employeeId => _compareEmployeeId(
          a.employee.employeeId,
          b.employee.employeeId,
        ),
        MemberSort.employee => _name(a).compareTo(_name(b)),
        MemberSort.team => normalizeLoose(
          a.employee.team,
        ).compareTo(normalizeLoose(b.employee.team)),
        MemberSort.seniority => a.employee.seniority.index.compareTo(
          b.employee.seniority.index,
        ),
        MemberSort.hours => a.totalCreditedHours.compareTo(
          b.totalCreditedHours,
        ),
        MemberSort.compliance => a.totalPercentage.compareTo(b.totalPercentage),
      };

  /// Numeric IDs by value ("9" before "10"); anything else as text.
  int _compareEmployeeId(String a, String b) {
    final numberA = int.tryParse(a.trim());
    final numberB = int.tryParse(b.trim());
    if (numberA != null && numberB != null) return numberA.compareTo(numberB);
    return a.compareTo(b);
  }
}
