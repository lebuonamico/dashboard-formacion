import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'dart:async';

import 'package:app_finnegans/features/imports/domain/import_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/app_top_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/imports/presentation/providers/import_providers.dart';
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

      final imported = await container.read(importLmsCertificationsProvider)(
        ImportFile(
          name: result.files.single.name,
          bytes: result.files.single.bytes!,
        ),
        refresh: () async {
          container.invalidate(lmsCertificationsProvider);
          await Future.wait([container.read(lmsCertificationsProvider.future)]);
        },
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Se importaron ${imported.processedRecords} certificaciones LMS.',
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

      final imported = await container.read(importPayrollProvider)(
        ImportFile(
          name: result.files.single.name,
          bytes: result.files.single.bytes!,
        ),
        refresh: () async {
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
        'Se importaron ${imported.processedRecords} registros desde ${result.files.single.name}.',
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

      final imported = await container.read(importCourseCatalogProvider)(
        ImportFile(
          name: result.files.single.name,
          bytes: result.files.single.bytes!,
        ),
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
        'Se cargaron ${imported.processedRecords} cursos desde ${result.files.single.name}.',
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

      final imported = await container.read(importCrmTimeEntriesProvider)(
        ImportFile(
          name: result.files.single.name,
          bytes: result.files.single.bytes!,
        ),
        loadCatalog: () => container.read(coursesProvider.future),
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
        'Se cargaron ${imported.processedRecords} registros desde ${result.files.single.name}.',
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
