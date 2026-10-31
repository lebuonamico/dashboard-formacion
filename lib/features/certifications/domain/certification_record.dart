import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';

/// An LMS certification joined with the payroll and the catalog.
class CertificationRecord {
  final LmsCertification certification;
  final Employee? employee;
  final Course? course;
  final CourseCategory? lmsCategory;

  /// Without a catalog course the completion credits no hours.
  final bool courseOutsideCatalog;
  final bool employeeIdOutsidePayroll;
  final bool outsideCalculation;

  const CertificationRecord({
    required this.certification,
    required this.employee,
    required this.course,
    required this.lmsCategory,
    required this.courseOutsideCatalog,
    required this.employeeIdOutsidePayroll,
    required this.outsideCalculation,
  });
}

/// Summary of every imported certification, regardless of the filters.
class CertificationKpis {
  final int total;
  final int completed;
  final int pending;
  final int outsideCalculation;
  final int certifiedEmployees;
  final double completedPercentage;

  const CertificationKpis({
    required this.total,
    required this.completed,
    required this.pending,
    required this.outsideCalculation,
    required this.certifiedEmployees,
    required this.completedPercentage,
  });
}
