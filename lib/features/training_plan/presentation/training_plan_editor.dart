import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_editor_provider.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';
import 'package:app_finnegans/features/training_plan/presentation/training_plan_hours_format.dart';
import 'package:app_finnegans/features/training_plan/presentation/training_plan_messages.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan_service.dart';

/// Edita las horas mensuales requeridas por categoría para cada seniority.
/// Cada guardado es una versión que rige desde el mes elegido: los meses
/// anteriores conservan el plan que tenían.
class TrainingPlanEditor extends ConsumerStatefulWidget {
  const TrainingPlanEditor({super.key});

  @override
  ConsumerState<TrainingPlanEditor> createState() => _TrainingPlanEditorState();
}

class _TrainingPlanEditorState extends ConsumerState<TrainingPlanEditor> {
  final _controllers = {
    for (final seniority in Seniority.values)
      for (final category in CourseCategory.values)
        (seniority, category): TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    ref.listenManual(trainingPlanEditorProvider, (_, next) {
      if (next.value case final draft?) _showTexts(draft.texts);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showTexts(Map<PlanCell, String> texts) {
    for (final MapEntry(key: cell, value: controller) in _controllers.entries) {
      final text = texts[cell] ?? '';
      if (controller.text != text) controller.text = text;
    }
  }

  TrainingPlanEditorNotifier get _editor =>
      ref.read(trainingPlanEditorProvider.notifier);

  Future<void> _chooseMonth(
    TrainingPlanDraft draft,
    int year,
    int month,
  ) async {
    if (draft.validFrom == DateTime(year, month)) return;
    if (draft.hasChanges) {
      final discard = await showConfirmationDialog(
        context,
        title: 'Descartar cambios',
        message: 'Hay cambios sin guardar en el plan. ¿Querés descartarlos?',
        confirmLabel: 'Descartar',
        confirmKey: const Key('plan_confirmar_descarte'),
      );
      if (!discard || !mounted) return;
    }
    ref.read(trainingPlanEditorMonthProvider.notifier).select(year, month);
  }

  Future<void> _save(TrainingPlanDraft draft) async {
    final validity =
        '${monthName(draft.validFrom.month)} ${draft.validFrom.year}';
    final confirmed = draft.isPastMonth
        ? await showConfirmationDialog(
            context,
            title: 'Guardar plan de un mes pasado',
            message:
                '$validity ya fue evaluado. Guardar recalcula el cumplimiento '
                'de ese mes y de todos los siguientes, también los que ya se '
                'revisaron.',
            confirmLabel: 'Guardar igual',
            confirmColor: context.colors.warning.text,
            confirmKey: const Key('plan_confirmar'),
          )
        : await showConfirmationDialog(
            context,
            title: 'Guardar plan',
            message:
                'El plan rige desde $validity y el cumplimiento se recalcula '
                'desde ese mes.',
            confirmLabel: 'Guardar',
            confirmKey: const Key('plan_confirmar'),
          );
    if (!confirmed || !mounted) return;
    await runWithFeedback(
      context,
      action: _editor.save,
      success: 'Plan guardado: rige desde $validity.',
      failure: (error) => error is FormatException
          ? error.message
          : 'No se pudo guardar el plan: $error',
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(trainingPlanEditorProvider);
    final draft = draftAsync.value;
    if (draft == null) {
      return draftAsync.hasError
          ? Text(
              'No se pudo cargar el plan de formación: ${draftAsync.error}',
              style: TextStyle(color: context.colors.danger.text),
            )
          : const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
    }
    final saving = draft.isSaving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Validity(
          draft: draft,
          today: ref.watch(clockProvider)(),
          onChooseMonth: saving
              ? null
              : (year, month) => _chooseMonth(draft, year, month),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _PlanTable(
            draft: draft,
            controllers: _controllers,
            service: ref.watch(trainingPlanServiceProvider),
            onChanged: saving ? null : _editor.setHours,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              key: const Key('plan_restaurar'),
              onPressed: saving ? null : _editor.restoreDefaults,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restaurar valores por defecto'),
            ),
            TextButton(
              key: const Key('plan_descartar'),
              onPressed: draft.hasChanges && !saving ? _editor.discard : null,
              child: const Text('Descartar cambios'),
            ),
            FilledButton.icon(
              key: const Key('plan_guardar'),
              onPressed: draft.editedPlan != null && draft.hasChanges && !saving
                  ? () => _save(draft)
                  : null,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar plan'),
            ),
          ],
        ),
      ],
    );
  }
}

String _monthLabel(DateTime date) =>
    '${monthName(date.month).toLowerCase()} ${date.year}';

class _Validity extends StatelessWidget {
  final TrainingPlanDraft draft;
  final DateTime today;
  final void Function(int year, int month)? onChooseMonth;

  const _Validity({
    required this.draft,
    required this.today,
    required this.onChooseMonth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final year = draft.validFrom.year;
    final month = draft.validFrom.month;
    final firstYear = [
      today.year - 1,
      ...draft.history.versions.map((version) => version.validFrom.year),
    ].reduce((a, b) => a < b ? a : b);
    final years = [for (var y = firstYear; y <= today.year + 1; y++) y];
    final current = draft.currentVersion;
    final next = draft.nextVersion;
    final choose = onChooseMonth;
    final noteStyle = context.textTheme.bodySmall!.copyWith(
      color: cs.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Rige desde',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            DropdownButton<int>(
              key: const Key('plan_mes'),
              value: month,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(monthName(m))),
              ],
              onChanged: choose == null
                  ? null
                  : (value) => value == null ? null : choose(year, value),
            ),
            DropdownButton<int>(
              key: const Key('plan_anio'),
              value: year,
              items: [
                for (final option in years)
                  DropdownMenuItem(value: option, child: Text('$option')),
              ],
              onChanged: choose == null
                  ? null
                  : (value) => value == null ? null : choose(value, month),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          current == null
              ? 'Hasta ahora ese mes usa los valores por defecto.'
              : current.validFrom == draft.validFrom
              ? 'Estás editando la versión que rige desde ese mes.'
              : 'Hasta ahora ese mes usa la versión de '
                    '${_monthLabel(current.validFrom)}.',
          style: noteStyle,
        ),
        if (next != null)
          Text(
            'Lo que guardes rige hasta ${_monthLabel(next.validFrom)}, '
            'cuando empieza la versión siguiente.',
            style: noteStyle,
          ),
        if (draft.isPastMonth)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: colors.warning.text,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Es un mes pasado: guardar recalcula los meses ya '
                    'evaluados desde ${monthName(month)} $year.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.warning.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (draft.history.versions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final version in draft.history.versions)
                ActionChip(
                  label: Text('Desde ${_monthLabel(version.validFrom)}'),
                  onPressed: choose == null
                      ? null
                      : () => choose(
                          version.validFrom.year,
                          version.validFrom.month,
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PlanTable extends StatelessWidget {
  static const _widthSeniority = 170.0;
  static const _hoursWidth = 104.0;
  static const _widthTotal = 90.0;

  final TrainingPlanDraft draft;
  final Map<PlanCell, TextEditingController> controllers;
  final TrainingPlanService service;
  final void Function(Seniority, CourseCategory, String)? onChanged;

  const _PlanTable({
    required this.draft,
    required this.controllers,
    required this.service,
    required this.onChanged,
  });

  double? _value(Seniority seniority, CourseCategory category) =>
      parsePlanHours(draft.texts[(seniority, category)] ?? '');

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final headerStyle = context.textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const FixedColumnWidth(_widthSeniority),
        for (var i = 1; i <= CourseCategory.values.length; i++)
          i: const FixedColumnWidth(_hoursWidth),
        CourseCategory.values.length + 1: const FixedColumnWidth(_widthTotal),
      },
      children: [
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Seniority', style: headerStyle),
            ),
            for (final category in CourseCategory.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 12),
                child: Tooltip(
                  message: category.label,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.category(category).text,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(category.shortLabel, style: headerStyle),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Total',
                textAlign: TextAlign.end,
                style: headerStyle,
              ),
            ),
          ],
        ),
        for (final seniority in Seniority.values) _row(context, seniority),
      ],
    );
  }

  TableRow _row(BuildContext context, Seniority seniority) {
    final cs = context.colorScheme;
    final values = [
      for (final category in CourseCategory.values) _value(seniority, category),
    ];
    final total = values.every((value) => service.hoursIssue(value) == null)
        ? values.fold<double>(0, (sum, value) => sum + value!)
        : null;

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SeniorityChip(seniority: seniority),
          ),
        ),
        for (final category in CourseCategory.values)
          _HoursField(
            fieldKey: Key('plan_${seniority.name}_${category.name}'),
            controller: controllers[(seniority, category)]!,
            error: hoursErrorText(service, _value(seniority, category)),
            modified:
                _value(seniority, category) !=
                draft.base.hours[seniority]![category],
            onChanged: onChanged == null
                ? null
                : (text) => onChanged!(seniority, category, text),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (total == 0)
              Tooltip(
                message: 'Sin objetivo: cuenta como cumplido.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: context.colors.warning.text,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              total == null ? '—' : '${formatPlanHours(total)} h',
              key: Key('plan_total_${seniority.name}'),
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HoursField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String? error;
  final bool modified;
  final ValueChanged<String>? onChanged;

  const _HoursField({
    required this.fieldKey,
    required this.controller,
    required this.error,
    required this.modified,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
      child: TextField(
        key: fieldKey,
        controller: controller,
        enabled: onChanged != null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          suffixText: 'h',
          errorText: error,
          errorMaxLines: 2,
          filled: error == null && modified,
          fillColor: cs.primaryContainer.withValues(alpha: 0.45),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
