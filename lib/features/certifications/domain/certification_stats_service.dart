import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/certifications/domain/certification_record.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';

class CertificationStatsService {
  final CourseClassificationService classification;

  const CertificationStatsService({required this.classification});

  /// Every certification joined with the payroll and the catalog: the most
  /// recent first, the ones without a date (pending) last. Courses match with
  /// the compliance normalizer, so "outside the catalog" is exactly what does
  /// not credit hours.
  List<CertificationRecord> join({
    required List<LmsCertification> certifications,
    required List<Employee> employees,
    required List<Course> courses,
  }) {
    final employeesById = {for (final e in employees) e.employeeId: e};
    final coursesByName = {
      for (final course in courses) normalizeKey(course.name): course,
    };
    return certifications.map((certification) {
      final employee = employeesById[certification.employeeId];
      final course = coursesByName[normalizeKey(certification.courseName)];
      return CertificationRecord(
        certification: certification,
        employee: employee,
        course: course,
        lmsCategory: course == null ? null : classification.lmsCategory(course),
        courseOutsideCatalog: course == null,
        employeeIdOutsidePayroll: employee == null,
        outsideCalculation: course == null || employee == null,
      );
    }).toList()..sort(_byDateThenName);
  }

  CertificationKpis kpis(List<CertificationRecord> records) {
    final completed = records
        .where((record) => record.certification.isCompleted)
        .length;
    return CertificationKpis(
      total: records.length,
      completed: completed,
      pending: records.length - completed,
      outsideCalculation: records
          .where((record) => record.outsideCalculation)
          .length,
      certifiedEmployees: records
          .where(
            (record) =>
                record.certification.isCompleted &&
                !record.employeeIdOutsidePayroll,
          )
          .map((record) => record.certification.employeeId)
          .toSet()
          .length,
      completedPercentage: records.isEmpty
          ? 0
          : completed / records.length * 100,
    );
  }

  static int _byDateThenName(CertificationRecord a, CertificationRecord b) {
    final dateA = a.certification.completedAt;
    final dateB = b.certification.completedAt;
    if (dateA != null && dateB != null) {
      final byDate = dateB.compareTo(dateA);
      if (byDate != 0) return byDate;
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }
    return a.certification.courseName.toLowerCase().compareTo(
      b.certification.courseName.toLowerCase(),
    );
  }
}
