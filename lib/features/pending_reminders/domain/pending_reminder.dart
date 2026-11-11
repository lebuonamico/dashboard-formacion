class PendingCourse {
  final String courseId;
  final String courseName;

  const PendingCourse({required this.courseId, required this.courseName});
}

/// One email: an employee and the pending courses it reminds them of.
class PendingReminder {
  final String employeeId;
  final String fullName;
  final String email;
  final List<PendingCourse> courses;

  const PendingReminder({
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.courses,
  });
}

enum SkipReason { outsidePayroll, inactive, missingEmail }

/// An employee with pending courses who gets no email.
class SkippedReminder {
  final String employeeId;

  /// Empty when the employee ID is outside the payroll.
  final String fullName;
  final int pendingCourses;
  final SkipReason reason;

  const SkippedReminder({
    required this.employeeId,
    required this.fullName,
    required this.pendingCourses,
    required this.reason,
  });
}

/// What the confirmation dialog shows before anything is sent.
class PendingReminderPlan {
  final List<PendingReminder> reminders;
  final List<SkippedReminder> skipped;

  const PendingReminderPlan({required this.reminders, required this.skipped});

  static const empty = PendingReminderPlan(reminders: [], skipped: []);

  int get courseCount =>
      reminders.fold(0, (total, reminder) => total + reminder.courses.length);
}

/// What the server did: it checks again who can be reached, so its counts
/// may differ from the plan.
class PendingReminderResult {
  final int sent;
  final int failed;
  final int skipped;

  const PendingReminderResult({
    required this.sent,
    required this.failed,
    required this.skipped,
  });
}
