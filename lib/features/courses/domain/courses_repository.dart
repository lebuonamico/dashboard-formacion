import 'package:app_finnegans/features/imports/domain/upsert_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';

abstract class CoursesRepository {
  Future<List<Course>> getCourses({String? id, String? name});
  Future<void> replaceCourses(List<Course> courses);
  Future<void> resetToMock();
}

extension CoursesUpsert on CoursesRepository {
  Future<UpsertResult> syncSnapshotWithResult(List<Course> items) async {
    if (items.isEmpty || items.any((item) => item.id.trim().isEmpty)) {
      throw const FormatException(
        'La foto de Cursos está vacía o tiene claves inválidas.',
      );
    }
    if (this is SnapshotRepository<Course>) {
      return (this as SnapshotRepository<Course>).syncSnapshotWithResult(items);
    }
    final present = items.map((item) => item.id).toSet();
    final changes = [
      for (final item in items) item.copyWith(active: true),
      for (final item in await getCourses())
        if (item.isActive && !present.contains(item.id))
          item.copyWith(active: false),
    ];
    final result = await upsertCoursesWithResult(changes);
    return UpsertResult(
      processedRecords: items.length,
      inserted: result.inserted,
      updated: result.updated,
    );
  }

  Future<UpsertResult> upsertCoursesWithResult(List<Course> items) async {
    if (items.isEmpty) return UpsertResult.empty;
    if (this is CountedUpsertRepository<Course>) {
      return (this as CountedUpsertRepository<Course>).upsertWithResult(items);
    }
    await upsertCourses(items);
    return UpsertResult(processedRecords: items.length);
  }

  Future<void> upsertCourses(List<Course> items) async {
    if (items.isEmpty) return;
    if (this is UpsertRepository<Course>) {
      await (this as UpsertRepository<Course>).upsert(items);
      return;
    }
    final merged = <String, Course>{};
    for (final item in [...await getCourses(), ...items]) {
      merged[item.id] = item;
    }
    await replaceCourses(merged.values.toList());
  }
}
