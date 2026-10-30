import 'package:app_finnegans/features/courses/domain/course.dart';

String normalizeCourseName(String value) => value.trim().toLowerCase();

Course courseResolver(String name, List<Course> courses) {
  final matches = courses
      .where((c) => normalizeCourseName(c.name) == normalizeCourseName(name))
      .toList();
  if (name.trim().isEmpty || matches.length != 1) {
    throw FormatException('Curso inexistente o ambiguo: "$name".');
  }
  return matches.single;
}

DateTime? importDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final parts = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(text);
  if (parts != null) {
    final day = int.parse(parts[1]!);
    final month = int.parse(parts[2]!);
    final year = int.parse(parts[3]!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }
  final isoParts = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:$|[T ])',
  ).firstMatch(text);
  if (isoParts != null) {
    final year = int.parse(isoParts[1]!);
    final month = int.parse(isoParts[2]!);
    final day = int.parse(isoParts[3]!);
    final calendar = DateTime(year, month, day);
    if (calendar.year != year ||
        calendar.month != month ||
        calendar.day != day) {
      return null;
    }
    final hour = RegExp(r'[T ](\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(text);
    if (hour != null &&
        (int.parse(hour[1]!) > 23 ||
            int.parse(hour[2]!) > 59 ||
            int.parse(hour[3] ?? '0') > 59)) {
      return null;
    }
    final date = DateTime.tryParse(text);
    return date;
  }
  final serial = double.tryParse(text.replaceAll(',', '.'));
  if (serial == null || !serial.isFinite || serial < 1 || serial > 2958465) {
    return null;
  }
  return DateTime(
    1899,
    12,
    30,
  ).add(Duration(milliseconds: (serial * Duration.millisecondsPerDay).round()));
}

DateTime requiredDate(String value) {
  return importDate(value) ??
      (throw FormatException('Fecha inválida: "$value".'));
}
