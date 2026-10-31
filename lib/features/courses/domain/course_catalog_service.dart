import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:collection/collection.dart';

class CourseCatalogService {
  const CourseCatalogService();

  /// Course id for each normalized course name. Ambiguous names map to an
  /// empty id, so a filter never picks one of two homonyms at random.
  Map<String, String> idsByName(List<Course> courses) {
    final ids =
        groupBy(
          courses.where(
            (course) =>
                normalizeKey(course.name).isNotEmpty &&
                course.id.trim().isNotEmpty,
          ),
          (Course course) => normalizeKey(course.name),
        ).map((name, matches) {
          final distinct = matches.map((course) => course.id.trim()).toSet();
          return MapEntry(name, distinct.length == 1 ? distinct.single : '');
        });
    return Map.unmodifiable(ids);
  }

  /// [id] when present, otherwise the catalog id of [name].
  String courseIdFor(String? id, String name, Map<String, String> idsByName) =>
      (id?.trim().isNotEmpty ?? false)
      ? id!.trim()
      : idsByName[normalizeKey(name)] ?? '';

  /// Catalog courses by normalized name.
  Map<String, Course> byName(List<Course> courses) => {
    for (final course in courses) normalizeKey(course.name): course,
  };
}
