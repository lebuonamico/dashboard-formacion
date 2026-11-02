import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';

/// Recognises the category from the CRM Clasificación or the catalog
/// ("Habilidades de Negocio y Herramientas", "Horas de Dictado",
/// "Exploracion / Profundizacion"), ignoring case, accents and symbols.
class CourseCategoryParser {
  CourseCategoryParser();

  static const _names = {
    'habilidadesdenegocio': CourseCategory.businessSkills,
    'habilidadesblandas': CourseCategory.softSkills,
    'libresexploracion': CourseCategory.exploration,
    'dictadodecapacitaciones': CourseCategory.teaching,
  };

  /// It runs once per time entry over a handful of distinct texts, so each
  /// text is resolved only once.
  final _recognized = <String, CourseCategory?>{};

  CourseCategory? tryParse(String? text) {
    if (text == null) return null;
    return _recognized.putIfAbsent(text, () => _recognize(text));
  }

  CourseCategory? _recognize(String text) {
    final searched = normalizeKey(text);
    if (searched.isEmpty) return null;
    final exact = _names[searched];
    if (exact != null) return exact;
    if (searched.contains('negocio') || searched.contains('business')) {
      return CourseCategory.businessSkills;
    }
    if (searched.contains('blanda') || searched.contains('soft')) {
      return CourseCategory.softSkills;
    }
    if (searched.contains('dictad') || searched.contains('impart')) {
      return CourseCategory.teaching;
    }
    if (searched.contains('libre') ||
        searched.contains('exploracion') ||
        searched.contains('profundizacion')) {
      return CourseCategory.exploration;
    }
    return null;
  }
}
