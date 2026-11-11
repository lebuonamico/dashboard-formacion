import 'package:app_finnegans/features/certifications/domain/certification_record.dart';
import 'package:app_finnegans/features/employees/domain/employee_lookup_service.dart';
import 'package:app_finnegans/features/pending_reminders/domain/pending_reminder.dart';

class PendingReminderService {
  final EmployeeLookupService lookup;

  const PendingReminderService({this.lookup = const EmployeeLookupService()});

  /// One reminder per employee with the pending courses among [records],
  /// which are already filtered: with a course filter only that course is
  /// reminded. Completed certifications never count.
  PendingReminderPlan plan(List<CertificationRecord> records) {
    final pendingByEmployee = <String, List<CertificationRecord>>{};
    for (final record in records) {
      if (record.certification.isCompleted) continue;
      final employeeId = record.certification.employeeId.trim();
      if (employeeId.isEmpty) continue;
      pendingByEmployee.putIfAbsent(employeeId, () => []).add(record);
    }

    final reminders = <PendingReminder>[];
    final skipped = <SkippedReminder>[];
    for (final MapEntry(key: employeeId, value: pending)
        in pendingByEmployee.entries) {
      final courses = _courses(pending);
      final employee = pending.first.employee;
      final reason = switch (employee) {
        null => SkipReason.outsidePayroll,
        _ when !employee.isActive => SkipReason.inactive,
        _ when employee.email.trim().isEmpty => SkipReason.missingEmail,
        _ => null,
      };
      if (reason != null) {
        skipped.add(
          SkippedReminder(
            employeeId: employeeId,
            fullName: employee == null ? '' : lookup.fullName(employee),
            pendingCourses: courses.length,
            reason: reason,
          ),
        );
        continue;
      }
      reminders.add(
        PendingReminder(
          employeeId: employeeId,
          fullName: lookup.fullName(employee!),
          email: employee.email.trim(),
          courses: courses,
        ),
      );
    }

    int byName(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());
    reminders.sort((a, b) => byName(a.fullName, b.fullName));
    skipped.sort((a, b) => byName(a.fullName, b.fullName));
    return PendingReminderPlan(reminders: reminders, skipped: skipped);
  }

  /// The courses once each, by name. The catalog ID wins over the imported
  /// one, which local mode may not have.
  List<PendingCourse> _courses(List<CertificationRecord> pending) {
    final byId = <String, PendingCourse>{};
    for (final record in pending) {
      final name = record.course?.name ?? record.certification.courseName;
      final id =
          record.course?.id ?? record.certification.courseId ?? name.trim();
      byId.putIfAbsent(
        id,
        () => PendingCourse(courseId: id, courseName: name.trim()),
      );
    }
    return byId.values.toList()..sort(
      (a, b) =>
          a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase()),
    );
  }
}
