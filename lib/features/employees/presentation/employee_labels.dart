import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';

extension SeniorityLabel on Seniority {
  String get label => switch (this) {
    Seniority.trainee => 'Trainee',
    Seniority.junior1 => 'Junior 1',
    Seniority.junior2 => 'Junior 2',
    Seniority.junior3 => 'Junior 3',
    Seniority.semisenior1 => 'Semisenior 1',
    Seniority.semisenior2 => 'Semisenior 2',
    Seniority.semisenior3 => 'Semisenior 3',
    Seniority.senior1 => 'Senior 1',
    Seniority.senior2 => 'Senior 2',
    Seniority.senior3 => 'Senior 3',
    Seniority.manager => 'Manager',
  };
}

extension EmployeeName on Employee {
  String get fullName => const EmployeeLookupService().fullName(this);
}
