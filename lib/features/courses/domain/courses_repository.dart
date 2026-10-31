import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

abstract interface class CoursesRepository {
  Future<List<Course>> getCourses();

  Future<UpsertResult> upsert(List<Course> courses);
}
