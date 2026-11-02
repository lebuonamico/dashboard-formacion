import 'package:app_finnegans/features/courses/domain/course_catalog_service.dart';
import 'package:app_finnegans/features/courses/domain/course_classification_service.dart';
import 'package:app_finnegans/features/courses/domain/course_stats_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final courseCatalogServiceProvider = Provider<CourseCatalogService>(
  (ref) => const CourseCatalogService(),
);

final courseClassificationServiceProvider =
    Provider<CourseClassificationService>(
      (ref) => CourseClassificationService(),
    );

final courseStatsServiceProvider = Provider<CourseStatsService>(
  (ref) => CourseStatsService(
    classification: ref.watch(courseClassificationServiceProvider),
  ),
);
