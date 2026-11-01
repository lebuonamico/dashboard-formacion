import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/compliance/domain/employee_compliance.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry_record.dart';

/// An employee's profile for the selected period.
class EmployeeDetail {
  final Employee employee;
  final EmployeeCompliance compliance;
  final bool hasPeriodData;

  /// The period's CRM entries grouped by course, sorted by course name.
  final List<CourseTimeEntries> timeEntryGroups;

  /// The period's certifications, most recent first.
  final List<CertificationDetail> certifications;
  final List<TaughtCourse> taughtCourses;
  final double crmHours;

  /// Catalog workload of the period's completed certifications.
  final double creditedLmsHours;

  const EmployeeDetail({
    required this.employee,
    required this.compliance,
    required this.hasPeriodData,
    required this.timeEntryGroups,
    required this.certifications,
    required this.taughtCourses,
    required this.crmHours,
    required this.creditedLmsHours,
  });
}

/// A certification with its catalog course, `null` when the name is not in
/// the catalog.
class CertificationDetail {
  final LmsCertification certification;
  final Course? course;

  const CertificationDetail({required this.certification, this.course});
}

/// A course the employee logged in the CRM as taught, with the period's hours.
class TaughtCourse {
  final String code;
  final String name;
  final String area;
  final double hours;

  const TaughtCourse({
    required this.code,
    required this.name,
    required this.area,
    required this.hours,
  });
}

/// The CRM entries of one course.
class CourseTimeEntries {
  /// Stable id of the group, to keep each tile's expanded state.
  final String key;
  final String courseName;

  /// Most recent first.
  final List<CrmTimeEntryRecord> records;
  final double hours;

  /// The employee completed the course in the LMS, in any period.
  final bool isCompleted;

  const CourseTimeEntries({
    required this.key,
    required this.courseName,
    required this.records,
    required this.hours,
    required this.isCompleted,
  });
}
