import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_notifier.dart';
import 'package:flutter/material.dart';

String importErrorMessage(Object error) => error is FormatException
    ? error.message
    : 'No se pudo importar el archivo: $error';

extension ImportFileTypeLabels on ImportFileType {
  /// Suffix of the widget keys (`importar_nomina`, `loading_nomina`…).
  String get keySuffix => switch (this) {
    ImportFileType.payroll => 'nomina',
    ImportFileType.courseCatalog => 'cursos',
    ImportFileType.timeEntries => 'horas',
    ImportFileType.certifications => 'finalizaciones',
  };

  String get sectionTitle => switch (this) {
    ImportFileType.payroll => 'Carga de nómina de empleados',
    ImportFileType.courseCatalog => 'Carga de cursos',
    ImportFileType.timeEntries => 'Carga de horas CRM',
    ImportFileType.certifications => 'Certificaciones LMS',
  };

  String get sectionSubtitle => switch (this) {
    ImportFileType.payroll =>
      'Importá un archivo Excel o CSV con los datos de los empleados',
    ImportFileType.courseCatalog =>
      'Importá el catálogo de cursos desde Excel / CSV',
    ImportFileType.timeEntries =>
      'Importá las horas tomadas y dictadas desde el reporte de CRM',
    ImportFileType.certifications =>
      'Importá el estado y la fecha de finalización desde Excel',
  };

  String get title => switch (this) {
    ImportFileType.payroll => 'Importar nómina desde Excel / CSV',
    ImportFileType.courseCatalog => 'Importar cursos desde Excel / CSV',
    ImportFileType.timeEntries => 'Importar carga de horas desde Excel / CSV',
    ImportFileType.certifications => 'Importar certificaciones LMS desde Excel',
  };

  String get subtitle => switch (this) {
    ImportFileType.payroll =>
      'Cargá la nómina de empleados para actualizar el sistema',
    ImportFileType.courseCatalog =>
      'Tipos LMS: Habilidades de negocio y Habilidades blandas. El área y el instructor se completan desde las cursadas.',
    ImportFileType.timeEntries =>
      'Solo se consideran registros del proyecto 01 - Capacitación',
    ImportFileType.certifications =>
      'ID empleado, nombre del curso, finalización y fecha',
  };

  String get buttonLabel => switch (this) {
    ImportFileType.payroll => 'Cargar nómina',
    ImportFileType.courseCatalog => 'Cargar cursos',
    ImportFileType.timeEntries => 'Cargar horas',
    ImportFileType.certifications => 'Cargar Excel',
  };

  IconData get icon => switch (this) {
    ImportFileType.payroll => Icons.table_chart_outlined,
    ImportFileType.courseCatalog => Icons.school_outlined,
    ImportFileType.timeEntries => Icons.schedule,
    ImportFileType.certifications => Icons.verified_outlined,
  };

  ColorPair iconColors(BuildContext context) => switch (this) {
    ImportFileType.payroll => ColorPair(
      context.colorScheme.onPrimaryContainer,
      context.colorScheme.primaryContainer,
    ),
    ImportFileType.courseCatalog => context.colors.success,
    ImportFileType.timeEntries => context.colors.teaching,
    ImportFileType.certifications => context.colors.success,
  };

  List<String> get allowedExtensions => switch (this) {
    ImportFileType.certifications => const ['xlsx'],
    _ => const ['xlsx', 'csv'],
  };

  String get confirmationTitle => switch (this) {
    ImportFileType.payroll => 'Importar nómina',
    ImportFileType.courseCatalog => 'Importar catálogo de cursos',
    ImportFileType.timeEntries => 'Importar horas CRM',
    ImportFileType.certifications => 'Importar certificaciones LMS',
  };

  String confirmationMessage(String fileName) => switch (this) {
    ImportFileType.payroll =>
      'Vas a importar "$fileName" como la nómina vigente. Los colaboradores '
          'que no estén en el archivo quedan inactivos: no se borran y '
          'vuelven a estar activos si aparecen en una importación posterior.',
    ImportFileType.courseCatalog =>
      'Vas a importar "$fileName" como el catálogo vigente. Los cursos que '
          'no estén en el archivo quedan inactivos: no se borran y vuelven a '
          'estar activos si aparecen en una importación posterior.',
    ImportFileType.timeEntries =>
      'Vas a importar las horas de "$fileName". Se agregan las transacciones '
          'nuevas y se actualizan las que ya tienen el mismo ID. No se borra '
          'ninguna.',
    ImportFileType.certifications =>
      'Vas a importar las finalizaciones de "$fileName". Se agregan las '
          'nuevas y se actualizan las del mismo legajo y curso. No se borra '
          'ninguna.',
  };

  String successMessage(ImportOutcome outcome) {
    final count = outcome.result.processedRecords;
    return switch (this) {
      ImportFileType.payroll =>
        'Se importaron $count registros desde ${outcome.fileName}.',
      ImportFileType.courseCatalog =>
        'Se cargaron $count cursos desde ${outcome.fileName}.',
      ImportFileType.timeEntries =>
        'Se cargaron $count registros desde ${outcome.fileName}.',
      ImportFileType.certifications =>
        'Se importaron $count certificaciones LMS.',
    };
  }
}
