import 'package:app_finnegans/features/courses/data/courses_seed.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

class InMemoryCoursesRepository implements CoursesRepository {
  final Map<String, Course> _courses;

  InMemoryCoursesRepository([List<Course>? courses])
    : _courses = {
        for (final course in courses ?? coursesSeed) course.id: course,
      };

  @override
  Future<List<Course>> getCourses() async => [..._courses.values];

  @override
  Future<UpsertResult> upsert(List<Course> courses) async {
    final unique = {for (final course in courses) course.id: course};
    final inserted = unique.keys
        .where((id) => !_courses.containsKey(id))
        .length;
    _courses.addAll(unique);
    return UpsertResult(
      processedRecords: courses.length,
      inserted: inserted,
      updated: unique.length - inserted,
    );
  }
}
