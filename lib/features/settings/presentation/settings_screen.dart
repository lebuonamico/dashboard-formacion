import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'dart:async';

import 'package:app_finnegans/features/imports/data/spreadsheet_reader.dart';
import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_repository_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_repository_provider.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/crm_time_entries_repository_provider.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/lms_certifications_repository_provider.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_repository_provider.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/training_plan/presentation/training_plan_editor.dart';
import 'package:app_finnegans/core/text/text_normalizer.dart';
import 'package:app_finnegans/features/imports/data/payroll_file_parser.dart';
import 'package:app_finnegans/features/imports/data/course_catalog_file_parser.dart';
import 'package:app_finnegans/features/imports/data/crm_time_entries_file_parser.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _inProgressImports = <String>{};

  bool _startImport(String type) {
    if (_inProgressImports.contains(type)) return false;
    setState(() => _inProgressImports.add(type));
    return true;
  }

  void _finishImport(String type) {
    if (mounted) setState(() => _inProgressImports.remove(type));
  }

  Widget _importIcon(String type) => _inProgressImports.contains(type)
      ? SizedBox.square(
          key: Key('loading_$type'),
          dimension: 18,
          child: const CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.upload_file, size: 18);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Configuración del sistema'),

          // Contenido de Configuración
          Expanded(
            child: ListView(
              padding: screenPadding,
              children: [
                _buildImportSection(context),
                const SizedBox(height: 24),
                _buildCoursesSection(context),
                const SizedBox(height: 24),
                _buildTimeEntriesSection(context),
                const SizedBox(height: 24),
                _buildLmsSection(context),
                const SizedBox(height: 24),
                _buildTrainingPlanSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportSection(BuildContext context) {
    return _ConfigCard(
      title: 'Carga de nómina de empleados',
      subtitle: 'Importá un archivo Excel o CSV con los datos de los empleados',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SectionIcon(
            icon: Icons.table_chart_outlined,
            colors: ColorPair(
              context.colorScheme.onPrimaryContainer,
              context.colorScheme.primaryContainer,
            ),
          ),
          title: const Text(
            'Importar nómina desde Excel / CSV',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Cargá la nómina de empleados para actualizar el sistema',
          ),
          trailing: OutlinedButton.icon(
            key: const Key('importar_nomina'),
            onPressed: _inProgressImports.contains('nomina')
                ? null
                : _importPayrollFile,
            icon: _importIcon('nomina'),
            label: const Text('Cargar nómina'),
          ),
        ),
      ],
    );
  }

  Widget _buildCoursesSection(BuildContext context) {
    return _ConfigCard(
      title: 'Carga de cursos',
      subtitle: 'Importá el catálogo de cursos desde Excel / CSV',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SectionIcon(
            icon: Icons.school_outlined,
            colors: context.colors.success,
          ),
          title: const Text(
            'Importar cursos desde Excel / CSV',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Tipos LMS: Habilidades de negocio y Habilidades blandas. El área y el instructor se completan desde las cursadas.',
          ),
          trailing: OutlinedButton.icon(
            key: const Key('importar_cursos'),
            onPressed: _inProgressImports.contains('cursos')
                ? null
                : _importCoursesFile,
            icon: _importIcon('cursos'),
            label: const Text('Cargar cursos'),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeEntriesSection(BuildContext context) {
    return _ConfigCard(
      title: 'Carga de horas CRM',
      subtitle: 'Importá las horas tomadas y dictadas desde el reporte de CRM',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SectionIcon(
            icon: Icons.schedule,
            colors: context.colors.teaching,
          ),
          title: const Text(
            'Importar carga de horas desde Excel / CSV',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Solo se consideran registros del proyecto 01 - Capacitación',
          ),
          trailing: OutlinedButton.icon(
            key: const Key('importar_horas'),
            onPressed: _inProgressImports.contains('horas')
                ? null
                : _importTimeEntries,
            icon: _importIcon('horas'),
            label: const Text('Cargar horas'),
          ),
        ),
      ],
    );
  }

  Widget _buildLmsSection(BuildContext context) {
    return _ConfigCard(
      title: 'Certificaciones LMS',
      subtitle: 'Importá el estado y la fecha de finalización desde Excel',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SectionIcon(
            icon: Icons.verified_outlined,
            colors: context.colors.success,
          ),
          title: const Text(
            'Importar certificaciones LMS desde Excel',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'ID empleado, nombre del curso, finalización y fecha',
          ),
          trailing: OutlinedButton.icon(
            key: const Key('importar_finalizaciones'),
            onPressed: _inProgressImports.contains('finalizaciones')
                ? null
                : _importLmsCertifications,
            icon: _importIcon('finalizaciones'),
            label: const Text('Cargar Excel'),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingPlanSection() {
    return const _ConfigCard(
      title: 'Objetivo de formación por seniority',
      subtitle:
          'Horas mensuales requeridas por categoría. Cada cambio rige desde '
          'el mes que elijas: los meses anteriores conservan su objetivo.',
      children: [TrainingPlanEditor()],
    );
  }

  Future<void> _importLmsCertifications() async {
    if (!_startImport('finalizaciones')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final certifications = <LmsCertification>[];
      await container
          .read(importAuditServiceProvider)
          .run(
            fileType: 'finalizaciones',
            fileName: result.files.single.name,
            process: () async {
              final rowsBySheet = const SpreadsheetReader().readExcel(
                result.files.single.bytes!,
              );
              for (final rows in rowsBySheet.values) {
                if (rows.length < 2) continue;
                final headerIndex = _findLmsCertificationsRow(rows);
                if (headerIndex == -1) continue;
                final headers = rows[headerIndex]
                    .map((header) => normalizeKey(header.toString()))
                    .toList();
                final employeeIdIndex = _findColumn(headers, const [
                  'idempleadolegajo',
                  'idempleado',
                  'nlegajo',
                  'legajo',
                ]);
                final courseIndex = _findColumn(headers, const [
                  'nombredelcurso',
                  'nombrecurso',
                  'coursename',
                  'coursefullname',
                  'fullname',
                  'curso',
                ]);
                final completedIndex = _findColumn(headers, const [
                  'finalizoelcurso',
                  'finalizocurso',
                  'completado',
                  'completed',
                ]);
                final completedAtIndex = _findColumn(headers, const [
                  'fechadefinalizacion',
                  'fechafinalizacion',
                  'completiondate',
                  'datecompleted',
                  'timecompleted',
                ]);
                if (completedAtIndex == -1) {
                  throw const FormatException(
                    'Falta la columna Fecha de finalización en el Excel de Moodle.',
                  );
                }
                for (final row in rows.skip(headerIndex + 1)) {
                  if ([
                    employeeIdIndex,
                    courseIndex,
                    completedIndex,
                    completedAtIndex,
                  ].any((index) => index < 0 || index >= row.length)) {
                    continue;
                  }
                  final employeeId = row[employeeIdIndex].toString().trim();
                  final courseName = row[courseIndex].toString().trim();
                  final completed = _booleanMoodle(
                    row[completedIndex].toString(),
                  );
                  final completedAt = _dateMoodle(
                    row[completedAtIndex].toString(),
                  );
                  if (row[completedAtIndex].toString().trim().isNotEmpty &&
                      completedAt == null) {
                    throw FormatException(
                      'Fecha de finalización inválida para el legajo $employeeId: ${row[completedAtIndex]}.',
                    );
                  }
                  if (employeeId.isEmpty ||
                      courseName.isEmpty ||
                      completed == null) {
                    continue;
                  }
                  if (completed && completedAt == null) {
                    throw FormatException(
                      'Falta una fecha de finalización válida para el legajo $employeeId y el curso $courseName.',
                    );
                  }
                  certifications.add(
                    LmsCertification(
                      employeeId: employeeId,
                      courseName: courseName,
                      isCompleted: completed,
                      completedAt: completedAt,
                    ),
                  );
                }
              }

              if (certifications.isEmpty) {
                throw const FormatException(
                  'No se encontraron filas LMS válidas en el Excel.',
                );
              }
              return container
                  .read(lmsCertificationsRepositoryProvider)
                  .upsert(certifications);
            },
            refresh: () async {
              container.invalidate(lmsCertificationsProvider);
              await Future.wait([
                container.read(lmsCertificationsProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Se importaron ${certifications.length} certificaciones LMS.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.message);
    } on Object catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'No se pudo importar el archivo: $error');
    } finally {
      _finishImport('finalizaciones');
    }
  }

  int _findLmsCertificationsRow(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => normalizeKey(cell.toString()))
          .toList();
      if (_findColumn(headers, const [
                'idempleadolegajo',
                'idempleado',
                'nlegajo',
                'legajo',
              ]) !=
              -1 &&
          _findColumn(headers, const [
                'nombredelcurso',
                'nombrecurso',
                'coursename',
                'coursefullname',
                'fullname',
                'curso',
              ]) !=
              -1 &&
          _findColumn(headers, const [
                'finalizoelcurso',
                'finalizocurso',
                'completado',
                'completed',
              ]) !=
              -1 &&
          _findColumn(headers, const [
                'fechadefinalizacion',
                'fechafinalizacion',
                'completiondate',
                'datecompleted',
                'timecompleted',
              ]) !=
              -1) {
        return index;
      }
    }
    return -1;
  }

  bool? _booleanMoodle(String value) {
    return switch (normalizeKey(value)) {
      'true' || 'verdadero' || 'si' || 's' || '1' || 'yes' || 'y' => true,
      'false' ||
      'falso' ||
      'no' ||
      'n' ||
      '0' ||
      'incompleto' ||
      'pendiente' => false,
      _ => null,
    };
  }

  DateTime? _dateMoodle(String value) => importDate(value);

  Future<void> _importPayrollFile() async {
    if (!_startImport('nomina')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      var importedRecords = 0;
      await container
          .read(importAuditServiceProvider)
          .run(
            fileType: 'nomina',
            fileName: result.files.single.name,
            process: () async {
              final payroll = const PayrollFileParser().parse(
                ImportFile(
                  name: result.files.single.name,
                  bytes: result.files.single.bytes!,
                ),
              );
              importedRecords = payroll.rowCount;
              final orgStructureRepository = container.read(
                orgStructureRepositoryProvider,
              );
              final structure = await orgStructureRepository.getStructure();
              await orgStructureRepository.registerMissing(
                container
                    .read(orgStructureServiceProvider)
                    .missingFromPayroll(structure, payroll.employees),
              );
              final synced = await container
                  .read(snapshotSyncServiceProvider)
                  .syncPayroll(
                    container.read(employeesRepositoryProvider),
                    payroll.employees,
                  );
              return UpsertResult(
                processedRecords: payroll.rowCount,
                inserted: synced.inserted,
                updated: synced.updated,
              );
            },
            refresh: () async {
              // La nómina no cambia cursos, horas ni finalizaciones: lo que
              // depende de quién ve a quién se recalcula solo desde la nómina.
              container.invalidate(orgStructureNotifierProvider);
              container.invalidate(payrollProvider);
              container.invalidate(employeeHistoryProvider);
              await Future.wait([
                container.read(orgStructureNotifierProvider.future),
                container.read(employeesProvider.future),
                container.read(employeeHistoryProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Se importaron $importedRecords registros desde ${result.files.single.name}.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.message);
    } on Object catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'No se pudo importar el archivo: $error');
    } finally {
      _finishImport('nomina');
    }
  }

  Future<void> _importCoursesFile() async {
    if (!_startImport('cursos')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      var importedCourses = <Course>[];
      await container
          .read(importAuditServiceProvider)
          .run(
            fileType: 'cursos_lms',
            fileName: result.files.single.name,
            process: () async {
              importedCourses = CourseCatalogFileParser().parse(
                ImportFile(
                  name: result.files.single.name,
                  bytes: result.files.single.bytes!,
                ),
              );
              return container
                  .read(snapshotSyncServiceProvider)
                  .syncCourseCatalog(
                    container.read(coursesRepositoryProvider),
                    importedCourses,
                  );
            },
            refresh: () async {
              container.invalidate(coursesProvider);
              container.invalidate(crmTimeEntriesProvider);
              container.invalidate(dashboardTimeEntriesProvider);
              container.invalidate(lmsCertificationsProvider);
              await Future.wait([
                container.read(coursesProvider.future),
                container.read(crmTimeEntriesProvider.future),
                container.read(dashboardTimeEntriesProvider.future),
                container.read(lmsCertificationsProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Se cargaron ${importedCourses.length} cursos desde ${result.files.single.name}.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.message);
    } on Object catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'No se pudo importar el archivo: $error');
    } finally {
      _finishImport('cursos');
    }
  }

  Future<void> _importTimeEntries() async {
    if (!_startImport('horas')) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      await WidgetsBinding.instance.endOfFrame;
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      var importedTimeEntries = <CrmTimeEntry>[];
      await container
          .read(importAuditServiceProvider)
          .run(
            fileType: 'horas_crm',
            fileName: result.files.single.name,
            process: () async {
              final parsed = const CrmTimeEntriesFileParser().parse(
                ImportFile(
                  name: result.files.single.name,
                  bytes: result.files.single.bytes!,
                ),
              );
              final catalog = await container
                  .read(coursesRepositoryProvider)
                  .getCourses();
              final coursesByName = <String, Course>{};
              importedTimeEntries = parsed.map((entry) {
                final course =
                    coursesByName[normalizeLoose(entry.courseName)] ??=
                        courseResolver(entry.courseName, catalog);
                return entry.copyWith(
                  courseName: course.name,
                  courseId: course.id,
                );
              }).toList();
              return container
                  .read(crmTimeEntriesRepositoryProvider)
                  .upsert(importedTimeEntries);
            },
            refresh: () async {
              container.invalidate(crmTimeEntriesProvider);
              container.invalidate(dashboardTimeEntriesProvider);
              await Future.wait([
                container.read(crmTimeEntriesProvider.future),
                container.read(dashboardTimeEntriesProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Se cargaron ${importedTimeEntries.length} registros desde ${result.files.single.name}.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.message);
    } on Object catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, 'No se pudo importar el archivo: $error');
    } finally {
      _finishImport('horas');
    }
  }

  int _findColumn(List<String> headers, List<String> possible) {
    for (final possible in possible) {
      final index = headers.indexOf(possible);
      if (index != -1) return index;
    }
    return -1;
  }
}

class _ConfigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _ConfigCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: context.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Ícono de cada sección de importación sobre un fondo suave de su color.
class _SectionIcon extends StatelessWidget {
  final IconData icon;
  final ColorPair colors;

  const _SectionIcon({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: colors.text),
    );
  }
}
