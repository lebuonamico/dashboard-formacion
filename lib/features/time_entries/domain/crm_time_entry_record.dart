import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';

/// A CRM time entry joined with the payroll and the catalog.
class CrmTimeEntryRecord {
  final CrmTimeEntry timeEntry;
  final Employee? employee;
  final Course? course;
  final bool isTaught;

  const CrmTimeEntryRecord({
    required this.timeEntry,
    required this.employee,
    required this.course,
    required this.isTaught,
  });
}
