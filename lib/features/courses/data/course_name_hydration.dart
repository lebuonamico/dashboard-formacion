import 'package:app_finnegans/features/courses/domain/courses_repository.dart';

/// Hours and completions are stored with the course ID only: their name
/// comes from the catalog, read once for the whole batch.
Future<List<Map<String, dynamic>>> withCourseNames(
  List<Map<String, dynamic>> rows,
  CoursesRepository courses,
) async {
  if (rows.isEmpty) return rows;
  final names = {
    for (final course in await courses.getCourses()) course.id: course.name,
  };
  return rows.map((row) {
    final id = row['courseId']?.toString();
    if (id == null || id.isEmpty) {
      throw const FormatException('Falta la FK del curso.');
    }
    final name =
        names[id] ??
        (throw FormatException('Curso inexistente o inaccesible: $id.'));
    return {...row, 'courseName': name};
  }).toList();
}
