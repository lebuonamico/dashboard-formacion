import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/imports/domain/upsert_result.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/employees/domain/employees_repository.dart';
import 'package:app_finnegans/features/courses/domain/courses_repository.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entries_repository.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certifications_repository.dart';
import 'package:app_finnegans/features/courses/domain/course.dart';
import 'package:app_finnegans/features/time_entries/domain/crm_time_entry.dart';
import 'package:app_finnegans/features/certifications/domain/lms_certification.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/core/providers/core_providers.dart';
import 'package:app_finnegans/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:app_finnegans/features/time_entries/presentation/providers/time_entries_providers.dart';
import 'package:app_finnegans/features/courses/presentation/providers/courses_providers.dart';
import 'package:app_finnegans/features/employees/presentation/providers/employees_providers.dart';
import 'package:app_finnegans/features/org_structure/presentation/providers/org_structure_providers.dart';
import 'package:app_finnegans/features/training_plan/presentation/training_plan_editor.dart';

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
              final rowsBySheet = _readExcel(result.files.single.bytes!);
              for (final rows in rowsBySheet.values) {
                if (rows.length < 2) continue;
                final headerIndex = _findLmsCertificationsRow(rows);
                if (headerIndex == -1) continue;
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
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
                  .upsertCertificationsWithResult(certifications);
            },
            refresh: () async {
              container.invalidate(lmsCertificationsProvider);
              await Future.wait([
                container.read(lmsCertificationsProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se importaron ${certifications.length} certificaciones LMS.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
    } finally {
      _finishImport('finalizaciones');
    }
  }

  int _findLmsCertificationsRow(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
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
    return switch (_normalize(value)) {
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
              final extension = result.files.single.extension?.toLowerCase();
              final rowsBySheet = extension == 'xlsx'
                  ? _readExcel(result.files.single.bytes!)
                  : {
                      'CSV': const CsvToListConverter(shouldParseNumbers: false)
                          .convert(
                            utf8
                                .decode(result.files.single.bytes!)
                                .replaceFirst('\ufeff', ''),
                          ),
                    };
              final employeesRepository = container.read(
                employeesRepositoryProvider,
              );
              final coursesRepository = container.read(
                coursesRepositoryProvider,
              );
              final timeEntriesRepository = container.read(
                crmTimeEntriesRepositoryProvider,
              );

              var importedEmployees = <Employee>[];
              var importedCourses = <Course>[];
              var importedTimeEntries = <CrmTimeEntry>[];
              final validatedEmployees = <String, String>{};

              for (final sheet in rowsBySheet.entries) {
                final rows = sheet.value;
                if (!rows.any(_rowWithData)) continue;
                final headerIndex = _findHeadersRow(rows);
                if (headerIndex == -1) {
                  throw FormatException(
                    'No se reconocen los encabezados de nómina en la hoja "${sheet.key}". No se sincronizó la nómina.',
                  );
                }
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
                    .toList();
                _validateMasterHeaders(headers, sheet.key);
                final seniorityIndex = _findColumnSeniority(
                  headers,
                  rows,
                  headerIndex,
                );
                if (seniorityIndex == -1 ||
                    _findColumn(headers, const [
                          'fechadeingreso',
                          'fechaingreso',
                        ]) ==
                        -1) {
                  throw FormatException(
                    'Faltan las columnas Seniority o Fecha de ingreso en la hoja "${sheet.key}".',
                  );
                }

                for (
                  var dataRow = headerIndex + 1;
                  dataRow < rows.length;
                  dataRow++
                ) {
                  final row = rows[dataRow];
                  if (!_rowWithData(row)) continue;
                  final location = 'hoja "${sheet.key}", fila ${dataRow + 1}';
                  _validateRowColumns(row, headers, location);
                  final normalizedData = <String, String>{};
                  for (
                    var index = 0;
                    index < headers.length && index < row.length;
                    index++
                  ) {
                    normalizedData[headers[index]] = row[index]
                        .toString()
                        .trim();
                  }
                  if ((headers.contains('legajo') ||
                          headers.contains('nlegajo') ||
                          headers.contains('idempleado')) &&
                      (headers.contains('nombre') ||
                          headers.contains('nombreyapellido'))) {
                    final employeeData = _toCanonicalKeys(normalizedData, {
                      'nlegajo': 'legajo',
                      'idempleado': 'legajo',
                      'nombreyapellido': 'nombre',
                      'nivel': 'seniority',
                      'nivelseniority': 'seniority',
                      'niveldeseniority': 'seniority',
                      'senioridad': 'seniority',
                      'categoria': 'seniority',
                      'niveljerarquico': 'seniority',
                      'grado': 'seniority',
                      'email': 'mail',
                      'correo': 'mail',
                      'fechadeingreso': 'fechaIngreso',
                      'fechaingreso': 'fechaIngreso',
                      'correoelectronico': 'mail',
                      'gerencia': 'area',
                      'sector': 'area',
                      'departamento': 'area',
                      'unidad': 'area',
                      'team': 'equipo',
                      'equipo': 'equipo',
                      'equipogeneral': 'equipo',
                      'equipofuncional': 'equipo',
                      'equipoprincipal': 'equipo',
                      'manager': 'gerente',
                      'jefe': 'gerente',
                      'supervisor': 'gerente',
                      'reportaa': 'gerente',
                      for (final header in headers)
                        if (_isColumnSeniority(header)) header: 'seniority',
                    });
                    if (employeeData['legajo']?.toString().trim().isEmpty ??
                        true) {
                      throw FormatException('Falta el legajo en $location.');
                    }
                    if (employeeData['nombre']?.toString().trim().isEmpty ??
                        true) {
                      throw FormatException('Falta el nombre en $location.');
                    }
                    final seniorityText = seniorityIndex < row.length
                        ? row[seniorityIndex].toString().trim()
                        : '';
                    employeeData['seniority'] = _seniorityFromText(
                      seniorityText,
                      location,
                    ).name;
                    final hireDate =
                        employeeData['fechaIngreso']?.toString() ?? '';
                    final date = importDate(hireDate);
                    if (date == null) {
                      throw FormatException(
                        'Fecha de ingreso inválida en $location: "$hireDate".',
                      );
                    }
                    employeeData['fechaIngreso'] = date.toIso8601String();
                    final employee = Employee.fromJson(employeeData);
                    _validateMasterDuplicate(
                      validatedEmployees,
                      employee.employeeId,
                      employee.toJson(),
                      'legajo',
                      location,
                    );
                    importedEmployees = _replaceById(
                      importedEmployees,
                      employee,
                      (item) => item.employeeId,
                    );
                  } else if ((headers.contains('cursonombre') ||
                          headers.contains('nombrecurso') ||
                          headers.contains('curso')) &&
                      headers.contains('empleadolegajo')) {
                    final timeEntryData = _toCanonicalKeys(normalizedData, {
                      'cursonombre': 'cursoNombre',
                      'nombrecurso': 'cursoNombre',
                      'curso': 'cursoNombre',
                      'empleadolegajo': 'empleadoLegajo',
                      'horastotales': 'horasTotales',
                    });
                    final timeEntry = CrmTimeEntry.fromJson({
                      ...timeEntryData,
                      'tipo': TimeEntryKind.taken.name,
                    });
                    if (timeEntry.id.isNotEmpty) {
                      importedTimeEntries = _replaceById(
                        importedTimeEntries,
                        timeEntry,
                        (item) => item.id,
                      );
                    }
                  } else if (headers.contains('id') &&
                      headers.contains('nombre') &&
                      headers.contains('tipo')) {
                    final course = Course.fromJson(
                      _toCanonicalKeys(normalizedData, {
                        'areacurso': 'areaCurso',
                        'instructorlegajo': 'instructorLegajo',
                        'cargahorariahs': 'cargaHorariaHs',
                      }),
                    );
                    importedCourses = _replaceById(
                      importedCourses,
                      course,
                      (item) => item.id,
                    );
                  } else {
                    throw const FormatException(
                      'Encabezados no reconocidos en una hoja del archivo.',
                    );
                  }
                  importedRecords++;
                }
              }
              if (importedRecords == 0) {
                throw const FormatException('El archivo no tiene registros.');
              }

              // Las áreas y los equipos nuevos de la nómina se crean antes de
              // sincronizarla, así un fallo acá no deja empleados a medio
              // escribir. Los que ya existen no se repiten.
              final orgStructureRepository = container.read(
                orgStructureRepositoryProvider,
              );
              if (orgStructureRepository != null) {
                final structure = await orgStructureRepository.getStructure();
                await orgStructureRepository.registerMissing(
                  structure.missingFromPayroll(importedEmployees),
                );
              }

              var summary = UpsertResult.empty;
              // Leandro: llama a la sincronización de nómina para actualizar la foto vigente solo después de validar el archivo completo.
              summary += await employeesRepository.syncSnapshotWithResult(
                importedEmployees,
              );
              summary += await coursesRepository.upsertCoursesWithResult(
                importedCourses,
              );
              summary += await timeEntriesRepository
                  .upsertTimeEntriesWithResult(importedTimeEntries);
              return UpsertResult(
                processedRecords: importedRecords,
                inserted: summary.inserted,
                updated: summary.updated,
              );
            },
            refresh: () async {
              // La nómina no cambia cursos, horas ni finalizaciones: lo que
              // depende de quién ve a quién se recalcula solo desde la nómina.
              container.invalidate(orgStructureProvider);
              container.invalidate(payrollProvider);
              container.invalidate(employeeHistoryProvider);
              await Future.wait([
                container.read(orgStructureProvider.future),
                container.read(employeesProvider.future),
                container.read(employeeHistoryProvider.future),
              ]);
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se importaron $importedRecords registros desde ${result.files.single.name}.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
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

      final importedCourses = <Course>[];
      await container
          .read(importAuditServiceProvider)
          .run(
            fileType: 'cursos_lms',
            fileName: result.files.single.name,
            process: () async {
              final extension = result.files.single.extension?.toLowerCase();
              final rowsBySheet = extension == 'xlsx'
                  ? _readExcel(result.files.single.bytes!)
                  : {
                      'CSV': const CsvToListConverter(shouldParseNumbers: false)
                          .convert(
                            utf8
                                .decode(result.files.single.bytes!)
                                .replaceFirst('\ufeff', ''),
                          ),
                    };
              final repository = container.read(coursesRepositoryProvider);
              final validatedCourses = <String, String>{};

              for (final sheet in rowsBySheet.entries) {
                final rows = sheet.value;
                if (!rows.any(_rowWithData)) continue;
                final headerIndex = _findCoursesRow(rows);
                if (headerIndex == -1) {
                  throw FormatException(
                    'No se encontraron cursos con encabezados válidos en la hoja "${sheet.key}". No se sincronizó el catálogo.',
                  );
                }
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
                    .toList();
                _validateMasterHeaders(headers, sheet.key);
                final idIndex = _findColumn(headers, const [
                  'id',
                  'cursoid',
                  'courseid',
                  'iddelcurso',
                  'idcurso',
                  'shortname',
                  'courseshortname',
                  'codigo',
                ]);
                final nameIndex = _findColumn(headers, const [
                  'nombre',
                  'nombrecurso',
                  'course',
                  'coursename',
                  'fullname',
                  'coursefullname',
                  'nombrecompleto',
                  'titulo',
                ]);
                final typeIndex = _findColumn(headers, const ['clasificacion']);
                final hoursIndex = _findColumn(headers, const [
                  'cargahorariahs',
                  'cargahoraria',
                  'horas',
                  'hours',
                ]);
                if ([
                  idIndex,
                  nameIndex,
                  typeIndex,
                  hoursIndex,
                ].any((index) => index == -1)) {
                  throw FormatException(
                    'Faltan columnas obligatorias de ID, nombre, clasificación o carga horaria en la hoja "${sheet.key}".',
                  );
                }

                for (
                  var dataRow = headerIndex + 1;
                  dataRow < rows.length;
                  dataRow++
                ) {
                  final row = rows[dataRow];
                  if (!_rowWithData(row)) continue;
                  final location = 'hoja "${sheet.key}", fila ${dataRow + 1}';
                  _validateRowColumns(row, headers, location);
                  if ([
                    idIndex,
                    nameIndex,
                    typeIndex,
                    hoursIndex,
                  ].any((index) => index >= row.length)) {
                    throw FormatException(
                      'Faltan datos obligatorios del curso en $location.',
                    );
                  }
                  final id = row[idIndex].toString().trim();
                  final name = row[nameIndex].toString().trim();
                  if (id.isEmpty || name.isEmpty) {
                    throw FormatException(
                      'Falta el ID o nombre del curso en $location.',
                    );
                  }
                  final hoursText = row[hoursIndex].toString().trim();
                  final hours = double.tryParse(hoursText.replaceAll(',', '.'));
                  if (hours == null || !hours.isFinite || hours < 0) {
                    throw FormatException(
                      'Carga horaria inválida en $location: "$hoursText".',
                    );
                  }
                  final course = Course(
                    id: id,
                    name: name,
                    category: _courseCategoryFromText(
                      row[typeIndex].toString(),
                      location,
                    ),
                    courseArea: '',
                    instructorEmployeeId: '',
                    workloadHours: hours,
                  );
                  _validateMasterDuplicate(
                    validatedCourses,
                    course.id,
                    course.toJson(),
                    'ID de curso',
                    location,
                  );
                  importedCourses.add(course);
                }
              }

              if (importedCourses.isEmpty) {
                throw const FormatException(
                  'No se encontraron cursos. Verificá las columnas de ID y nombre.',
                );
              }
              // Leandro: llama a la sincronización del catálogo para dar altas, bajas y reactivaciones después de validar todas las hojas.
              return repository.syncSnapshotWithResult(importedCourses);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se cargaron ${importedCourses.length} cursos desde ${result.files.single.name}.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
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

      final importedTimeEntries = <CrmTimeEntry>[];
      await container
          .read(importAuditServiceProvider)
          .run(
            fileType: 'horas_crm',
            fileName: result.files.single.name,
            process: () async {
              final extension = result.files.single.extension?.toLowerCase();
              final rowsBySheet = extension == 'xlsx'
                  ? _readExcel(result.files.single.bytes!)
                  : {
                      'CSV': const CsvToListConverter(shouldParseNumbers: false)
                          .convert(
                            utf8
                                .decode(result.files.single.bytes!)
                                .replaceFirst('\ufeff', ''),
                          ),
                    };
              final repository = container.read(
                crmTimeEntriesRepositoryProvider,
              );
              final coursesRepository = container.read(
                coursesRepositoryProvider,
              );
              final coursesByName = <String, Course>{};

              var recognizedHeader = false;

              for (final rows in rowsBySheet.values) {
                if (rows.length < 2) continue;
                final headerIndex = _findTimeEntryRow(rows);
                if (headerIndex == -1) continue;
                recognizedHeader = true;
                final headers = rows[headerIndex]
                    .map((header) => _normalize(header.toString()))
                    .toList();
                final idIndex = _findColumnCrm(headers, 'id');
                final employeeIdIndex = _findColumnCrm(headers, 'legajo');
                final dateIndex = _findColumnCrm(headers, 'fecha');
                final courseIndex = headers.indexOf('curso');
                final hoursIndex = _findColumnCrm(headers, 'horas');
                if ([
                  idIndex,
                  employeeIdIndex,
                  dateIndex,
                  courseIndex,
                  hoursIndex,
                ].any((index) => index == -1)) {
                  continue;
                }

                for (final row in rows.skip(headerIndex + 1)) {
                  if (row.every((cell) => cell.toString().trim().isEmpty)) {
                    continue;
                  }
                  if ([
                    idIndex,
                    employeeIdIndex,
                    dateIndex,
                    courseIndex,
                    hoursIndex,
                  ].any((index) => index >= row.length)) {
                    throw const FormatException(
                      'Fila CRM incompleta: faltan columnas obligatorias.',
                    );
                  }
                  final courseName = row[courseIndex].toString().trim();
                  final course =
                      coursesByName[normalizeCourseName(
                        courseName,
                      )] ??= courseResolver(
                        courseName,
                        await coursesRepository.getCourses(name: courseName),
                      );
                  final date = _dateFromCell(row[dateIndex].toString());
                  String? source(String field) {
                    final index = headers.indexOf(field);
                    return index < 0 || index >= row.length
                        ? null
                        : row[index].toString().trim();
                  }

                  final hours =
                      double.tryParse(
                        row[hoursIndex].toString().replaceAll(',', '.'),
                      ) ??
                      0;
                  if (hours <= 0) continue;
                  final id = row[idIndex].toString().trim();
                  final employeeId = row[employeeIdIndex].toString().trim();
                  if (id.isEmpty || employeeId.isEmpty) continue;

                  importedTimeEntries.add(
                    CrmTimeEntry(
                      id: id,
                      courseName: course.name,
                      courseId: course.id,
                      caseRef: source('caso'),
                      courseDescription: source('descripcioncurso'),
                      classification: source('clasificacion'),
                      project: source('proyecto'),
                      projectItem: source('proyectoitem'),
                      description: source('descripcion'),
                      employeeId: employeeId,
                      date: date,
                      hours: hours,
                      kind: TimeEntryKind.taken,
                    ),
                  );
                }
              }

              if (importedTimeEntries.isEmpty) {
                if (!recognizedHeader) {
                  throw const FormatException(
                    'No se reconocieron los encabezados. El Excel debe incluir ID de transacción, legajo, fecha, curso y horas total.',
                  );
                }
                throw const FormatException(
                  'El archivo no tiene registros CRM válidos.',
                );
              }
              return repository.upsertTimeEntriesWithResult(
                importedTimeEntries,
              );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se cargaron ${importedTimeEntries.length} registros desde ${result.files.single.name}.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar el archivo: $error')),
      );
    } finally {
      _finishImport('horas');
    }
  }

  Map<String, List<List<dynamic>>> _readExcel(List<int> bytes) {
    final workbook = excel.Excel.decodeBytes(bytes);
    return {
      for (final entry in workbook.tables.entries)
        entry.key: entry.value.rows
            .map((row) => row.map((cell) => _cellValue(cell?.value)).toList())
            .toList(),
    };
  }

  String _cellValue(excel.CellValue? value) {
    if (value == null) return '';
    if (value is excel.TextCellValue) return _textSpan(value.value);
    if (value is excel.IntCellValue) return value.value.toString();
    if (value is excel.DoubleCellValue) return value.value.toString();
    if (value is excel.BoolCellValue) return value.value.toString();
    return value.toString();
  }

  String _textSpan(excel.TextSpan span) {
    return (span.text ?? '') +
        (span.children ?? const <excel.TextSpan>[]).map(_textSpan).join();
  }

  List<T> _replaceById<T>(List<T> current, T newValue, String Function(T) id) {
    final index = current.indexWhere((item) => id(item) == id(newValue));
    if (index == -1) return [...current, newValue];
    final result = [...current]..[index] = newValue;
    return result;
  }

  int _findHeadersRow(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
          .toSet();
      if ((headers.contains('legajo') ||
              headers.contains('nlegajo') ||
              headers.contains('idempleado')) &&
          (headers.contains('nombre') || headers.contains('nombreyapellido'))) {
        return index;
      }
    }
    return -1;
  }

  int _findCoursesRow(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
          .toSet();
      final hasId = headers.any(
        const {
          'id',
          'cursoid',
          'courseid',
          'iddelcurso',
          'idcurso',
          'shortname',
          'courseshortname',
          'codigo',
        }.contains,
      );
      final hasName = headers.any(
        const {
          'nombre',
          'nombrecurso',
          'course',
          'coursename',
          'fullname',
          'coursefullname',
          'nombrecompleto',
          'titulo',
        }.contains,
      );
      if (hasId && hasName) return index;
    }
    return -1;
  }

  int _findTimeEntryRow(List<List<dynamic>> rows) {
    for (var index = 0; index < rows.length && index < 15; index++) {
      final headers = rows[index]
          .map((cell) => _normalize(cell.toString()))
          .toSet();
      if (_findColumnCrm(headers.toList(), 'id') != -1 &&
          _findColumnCrm(headers.toList(), 'legajo') != -1 &&
          headers.contains('curso') &&
          _findColumnCrm(headers.toList(), 'fecha') != -1 &&
          _findColumnCrm(headers.toList(), 'horas') != -1) {
        return index;
      }
    }
    return -1;
  }

  int _findColumnCrm(List<String> headers, String field) {
    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      final matches = switch (field) {
        'id' => header.contains('transaccion') && header.contains('id'),
        'legajo' => header.contains('legajo'),
        'fecha' => header == 'fecha' || header.contains('fecha'),
        'horas' => header.contains('hora') && header.contains('total'),
        _ => false,
      };
      if (matches) return index;
    }
    return -1;
  }

  DateTime _dateFromCell(String value) => requiredDate(value);

  int _findColumn(List<String> headers, List<String> possible) {
    for (final possible in possible) {
      final index = headers.indexOf(possible);
      if (index != -1) return index;
    }
    return -1;
  }

  // Misma regla que la Clasificación del CRM.
  CourseCategory _courseCategoryFromText(String value, String location) {
    final type = CourseCategory.fromText(value);
    if (type == null) {
      throw FormatException('Clasificación inválida en $location: "$value".');
    }
    return type;
  }

  bool _rowWithData(List<dynamic> row) =>
      row.any((cell) => cell.toString().trim().isNotEmpty);

  void _validateMasterHeaders(List<String> headers, String sheet) {
    final seen = <String>{};
    for (final header in headers.where((header) => header.isNotEmpty)) {
      if (!seen.add(header)) {
        throw FormatException(
          'Encabezado duplicado "$header" en la hoja "$sheet".',
        );
      }
    }
  }

  void _validateRowColumns(
    List<dynamic> row,
    List<String> headers,
    String location,
  ) {
    for (var index = 0; index < row.length; index++) {
      if (row[index].toString().trim().isEmpty) continue;
      if (index >= headers.length || headers[index].isEmpty) {
        throw FormatException(
          'Hay datos sin encabezado de columna en $location.',
        );
      }
    }
  }

  void _validateMasterDuplicate(
    Map<String, String> validated,
    String id,
    Map<String, dynamic> data,
    String field,
    String location,
  ) {
    final content = jsonEncode(data);
    final previous = validated[id];
    if (previous != null && previous != content) {
      throw FormatException(
        'El $field "$id" tiene datos contradictorios en $location.',
      );
    }
    validated[id] = content;
  }

  Seniority _seniorityFromText(String value, String location) {
    final normalized = _normalize(value);
    final configured = Seniority.values.any(
      (seniority) =>
          _normalize(seniority.name) == normalized ||
          _normalize(seniority.label) == normalized,
    );
    final validAlias = RegExp(
      r'^trainee(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)?$|^t$'
      r'|^(?:junior|jr|j|senior|senor|sr|s)(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)?$'
      r'|^(?:semisenior|semisenor|ssr|ss)(?:[123]|i{1,3}|primero|segundo|tercero|uno|dos|tres)$'
      r'|^(?:manager|gerente|m)$',
    ).hasMatch(normalized);
    if (!configured && !validAlias) {
      throw FormatException('Seniority inválido en $location: "$value".');
    }
    return Seniority.fromString(value);
  }

  bool _isColumnSeniority(String header) {
    return header == 'seniority' ||
        header == 'senority' ||
        header.contains('seniority') ||
        header == 'senioridad' ||
        header == 'nivel' ||
        header == 'nivelseniority' ||
        header == 'niveldeseniority' ||
        header == 'niveljerarquico' ||
        header == 'categoria' ||
        header == 'grado';
  }

  int _findColumnSeniority(
    List<String> headers,
    List<List<dynamic>> rows,
    int headerIndex,
  ) {
    const specificHeaders = {
      'seniority',
      'senority',
      'nivelseniority',
      'niveldeseniority',
      'senioridad',
      'niveljerarquico',
    };
    final specificIndex = headers.indexWhere(specificHeaders.contains);
    if (specificIndex != -1) return specificIndex;

    for (var index = 0; index < headers.length; index++) {
      final header = headers[index];
      if (_isColumnSeniority(header)) {
        return index;
      }
    }

    var bestIndex = -1;
    var highestMatchCount = 0;
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      final matchCount = rows
          .skip(headerIndex + 1)
          .take(50)
          .where((row) => columnIndex < row.length)
          .map((row) => row[columnIndex].toString())
          .where(_looksLikeSeniorityValue)
          .length;
      if (matchCount > highestMatchCount) {
        highestMatchCount = matchCount;
        bestIndex = columnIndex;
      }
    }
    if (highestMatchCount > 0) return bestIndex;

    return -1;
  }

  bool _looksLikeSeniorityValue(String value) {
    final normalized = _normalize(value);
    return RegExp(
      r'^(?:senior|senor|sr|ssr|ss|junior|jr|j[123]|trainee|manager|gerente)',
    ).hasMatch(normalized);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  Map<String, dynamic> _toCanonicalKeys(
    Map<String, String> data,
    Map<String, String> aliases,
  ) {
    return {
      for (final entry in data.entries)
        aliases[entry.key] ?? entry.key: entry.value,
    };
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
