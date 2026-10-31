import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/compliance_service.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/employee_history_entry.dart';
import 'package:app_finnegans/features/org_structure/domain/user_scope.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

/// What the session sees, already filtered by its scope, plus the compliance
/// service with the training plan history.
class AssistantData {
  final List<Employee> employees;
  final List<EmployeeHistoryEntry> history;
  final List<Course> courses;
  final List<CrmTimeEntry> timeEntries;
  final List<LmsCertification> certifications;
  final UserScope scope;
  final ComplianceService complianceService;

  const AssistantData({
    required this.employees,
    required this.history,
    required this.courses,
    required this.timeEntries,
    required this.certifications,
    required this.scope,
    required this.complianceService,
  });
}
