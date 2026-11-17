import 'package:app_finnegans/core/clock/clock_provider.dart';
import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/widgets/error_data_state.dart';
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
import 'package:app_finnegans/features/courses/presentation/course_category_colors.dart';

/// Edits the monthly required hours per category for each seniority. Each
/// save is a version effective from the selected month: earlier months keep
/// the plan they had.
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
        confirmColor: context.colorScheme.error,
        confirmKey: const Key('plan_confirmar_descarte'),
      );
      if (!discard || !mounted) return;
    }
    ref.read(trainingPlanEditorMonthProvider.notifier).select(year, month);
  }

  Future<void> _discard() async {
    final discard = await showConfirmationDialog(
      context,
      title: 'Descartar cambios',
      message:
          'Se pierden los cambios sin guardar del plan. ¿Querés descartarlos?',
      confirmLabel: 'Descartar',
      confirmColor: context.colorScheme.error,
      confirmKey: const Key('plan_confirmar_descarte'),
    );
    if (discard && mounted) _editor.discard();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(trainingPlanEditorProvider)
        .when(
          skipLoadingOnReload: true,
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          // The draft only waits for the history: reading it again rebuilds
          // the draft too.
          error: (error, _) => ErrorDataState(
            title: 'No se pudo cargar el plan de formación',
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(trainingPlanHistoryProvider),
          ),
          data: (draft) {
            final saving = draft.isSaving;
            final saveButton = FilledButton.icon(
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
            );
            // A disabled button says nothing on its own.
            final saveHint = saving
                ? null
                : !draft.hasChanges
                ? 'No hay cambios para guardar'
                : draft.editedPlan == null
                ? 'Corregí los valores marcados para guardar'
                : null;
            // Below 840 px the table does not fit: one row per seniority.
            final compact = context.windowSize != WindowSize.expanded;
            final service = ref.watch(trainingPlanServiceProvider);
            final onChanged = saving ? null : _editor.setHours;
            final restoreButton = TextButton.icon(
              key: const Key('plan_restaurar'),
              onPressed: saving ? null : _editor.restoreDefaults,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restaurar valores por defecto'),
            );
            final discardButton = TextButton(
              key: const Key('plan_descartar'),
              onPressed: draft.hasChanges && !saving ? _discard : null,
              child: const Text('Descartar cambios'),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Validity(
                  draft: draft,
                  today: ref.watch(clockProvider)(),
                  stacked: compact,
                  onChooseMonth: saving
                      ? null
                      : (year, month) => _chooseMonth(draft, year, month),
                ),
                const SizedBox(height: 16),
                if (compact)
                  _PlanList(
                    draft: draft,
                    controllers: _controllers,
                    service: service,
                    onChanged: onChanged,
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _PlanTable(
                      draft: draft,
                      controllers: _controllers,
                      service: service,
                      onChanged: onChanged,
                    ),
                  ),
                const SizedBox(height: 16),
                if (compact)
                  _CompactActions(
                    saveButton: saveButton,
                    saveHint: saveHint,
                    restoreButton: restoreButton,
                    discardButton: discardButton,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      restoreButton,
                      discardButton,
                      if (saveHint == null)
                        saveButton
                      else
                        Tooltip(message: saveHint, child: saveButton),
                    ],
                  ),
              ],
            );
          },
        );
  }
}

String _monthLabel(DateTime date) =>
    '${monthName(date.month).toLowerCase()} ${date.year}';

double? _planValue(
  TrainingPlanDraft draft,
  Seniority seniority,
  CourseCategory category,
) => parsePlanHours(draft.texts[(seniority, category)] ?? '');

/// The seniority's monthly hours, or `null` while a value is invalid.
double? _seniorityTotal(
  TrainingPlanDraft draft,
  TrainingPlanService service,
  Seniority seniority,
) {
  final values = [
    for (final category in CourseCategory.values)
      _planValue(draft, seniority, category),
  ];
  return values.every((value) => service.hoursIssue(value) == null)
      ? values.fold<double>(0, (sum, value) => sum + value!)
      : null;
}

/// Below 840 px: save across the card, with its disabled reason as text
/// (touch screens have no hover), and the secondary actions below.
class _CompactActions extends StatelessWidget {
  final Widget saveButton;
  final String? saveHint;
  final Widget restoreButton;
  final Widget discardButton;

  const _CompactActions({
    required this.saveButton,
    required this.saveHint,
    required this.restoreButton,
    required this.discardButton,
  });

  @override
  Widget build(BuildContext context) {
    final hint = saveHint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 48, child: saveButton),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            key: const Key('plan_guardar_motivo'),
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [restoreButton, discardButton],
        ),
      ],
    );
  }
}

class _Validity extends StatelessWidget {
  final TrainingPlanDraft draft;
  final DateTime today;

  /// "Rige desde" above, and the month and year across the width.
  final bool stacked;
  final void Function(int year, int month)? onChooseMonth;

  const _Validity({
    required this.draft,
    required this.today,
    required this.stacked,
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

    final label = Text(
      'Rige desde',
      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
    );
    final monthOptions = [for (var m = 1; m <= 12; m++) (m, monthName(m))];
    final yearOptions = [for (final option in years) (option, '$option')];
    final ValueChanged<int>? onMonth = choose == null
        ? null
        : (value) => choose(year, value);
    final ValueChanged<int>? onYear = choose == null
        ? null
        : (value) => choose(value, month);
    final Widget monthField = stacked
        ? _CompactPicker(
            key: const Key('plan_mes'),
            tooltip: 'Mes',
            value: month,
            options: monthOptions,
            onChanged: onMonth,
          )
        : DropdownButton<int>(
            key: const Key('plan_mes'),
            value: month,
            items: [
              for (final (value, label) in monthOptions)
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: onMonth == null
                ? null
                : (value) => value == null ? null : onMonth(value),
          );
    final Widget yearField = stacked
        ? _CompactPicker(
            key: const Key('plan_anio'),
            tooltip: 'Año',
            value: year,
            options: yearOptions,
            onChanged: onYear,
          )
        : DropdownButton<int>(
            key: const Key('plan_anio'),
            value: year,
            items: [
              for (final (value, label) in yearOptions)
                DropdownMenuItem(value: value, child: Text(label)),
            ],
            onChanged: onYear == null
                ? null
                : (value) => value == null ? null : onYear(value),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stacked) ...[
          label,
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(flex: 3, child: monthField),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: yearField),
            ],
          ),
        ] else
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [label, monthField, yearField],
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

/// A dropdown look-alike for phones. Its menu opens in the root navigator:
/// a `DropdownButton` opens in the shell's, under the assistant's button,
/// which then covered the last month.
class _CompactPicker extends StatelessWidget {
  final String tooltip;
  final int value;
  final List<(int, String)> options;
  final ValueChanged<int>? onChanged;

  const _CompactPicker({
    super.key,
    required this.tooltip,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final enabled = onChanged != null;
    final label = options
        .firstWhere(
          (option) => option.$1 == value,
          orElse: () => (value, '$value'),
        )
        .$2;
    return LayoutBuilder(
      builder: (context, constraints) => PopupMenuButton<int>(
        tooltip: tooltip,
        enabled: enabled,
        useRootNavigator: true,
        initialValue: value,
        // As wide as the field, like a dropdown's menu.
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        onSelected: (selected) => onChanged?.call(selected),
        itemBuilder: (context) => [
          for (final (option, text) in options)
            PopupMenuItem(value: option, child: Text(text)),
        ],
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: enabled ? cs.onSurfaceVariant : cs.outline,
              ),
            ],
          ),
        ),
      ),
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
      _planValue(draft, seniority, category);

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
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
                  child: _CategoryLabel(category: category, style: headerStyle),
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
    final total = _seniorityTotal(draft, service, seniority);

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
            _TotalText(seniority: seniority, total: total),
          ],
        ),
      ],
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  final CourseCategory category;
  final TextStyle style;

  const _CategoryLabel({required this.category, required this.style});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: context.colors.category(category).text,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(child: Text(category.shortLabel, style: style)),
    ],
  );
}

class _TotalText extends StatelessWidget {
  final Seniority seniority;
  final double? total;

  const _TotalText({required this.seniority, required this.total});

  @override
  Widget build(BuildContext context) {
    final total = this.total;
    return Text(
      total == null ? '—' : '${formatPlanHours(total)} hs',
      key: Key('plan_total_${seniority.name}'),
      style: context.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurface,
      ),
    );
  }
}

/// The plan below 840 px: one expandable row per seniority with its total,
/// and the four categories two by two when it opens.
class _PlanList extends StatelessWidget {
  final TrainingPlanDraft draft;
  final Map<PlanCell, TextEditingController> controllers;
  final TrainingPlanService service;
  final void Function(Seniority, CourseCategory, String)? onChanged;

  const _PlanList({
    required this.draft,
    required this.controllers,
    required this.service,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final seniority in Seniority.values) ...[
        if (seniority != Seniority.values.first) const SizedBox(height: 8),
        _SeniorityTile(
          seniority: seniority,
          draft: draft,
          controllers: controllers,
          service: service,
          onChanged: onChanged,
        ),
      ],
    ],
  );
}

class _SeniorityTile extends StatelessWidget {
  final Seniority seniority;
  final TrainingPlanDraft draft;
  final Map<PlanCell, TextEditingController> controllers;
  final TrainingPlanService service;
  final void Function(Seniority, CourseCategory, String)? onChanged;

  const _SeniorityTile({
    required this.seniority,
    required this.draft,
    required this.controllers,
    required this.service,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    const categories = CourseCategory.values;
    final values = {
      for (final category in categories)
        category: _planValue(draft, seniority, category),
    };
    final base = draft.base.hours[seniority]!;
    final total = _seniorityTotal(draft, service, seniority);
    final hasErrors = values.values.any(
      (value) => hoursErrorText(service, value) != null,
    );
    final modified = categories.any(
      (category) => values[category] != base[category],
    );
    // A closed row still says what needs attention.
    final (String, Color)? status = hasErrors
        ? ('Hay valores para corregir', cs.error)
        : total == 0
        ? ('Sin objetivo: cuenta como cumplido', context.colors.warning.text)
        : modified
        ? ('Con cambios sin guardar', cs.primary)
        : null;
    final shape = RoundedRectangleBorder(
      side: BorderSide(color: hasErrors ? cs.error : cs.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    );
    final labelStyle = context.textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );
    final onChanged = this.onChanged;

    return ExpansionTile(
      key: Key('plan_seniority_${seniority.name}'),
      shape: shape,
      collapsedShape: shape,
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      title: Row(
        children: [
          Flexible(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SeniorityChip(seniority: seniority),
            ),
          ),
          const SizedBox(width: 8),
          _TotalText(seniority: seniority, total: total),
        ],
      ),
      subtitle: status == null
          ? null
          : Text(
              status.$1,
              style: context.textTheme.labelMedium?.copyWith(color: status.$2),
            ),
      children: [
        for (var i = 0; i < categories.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final category in categories.skip(i).take(2)) ...[
                if (category != categories[i]) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryLabel(category: category, style: labelStyle),
                      const SizedBox(height: 6),
                      _HoursField(
                        fieldKey: Key(
                          'plan_${seniority.name}_${category.name}',
                        ),
                        controller: controllers[(seniority, category)]!,
                        error: hoursErrorText(service, values[category]),
                        modified: values[category] != base[category],
                        padding: EdgeInsets.zero,
                        onChanged: onChanged == null
                            ? null
                            : (text) => onChanged(seniority, category, text),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _HoursField extends StatelessWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String? error;
  final bool modified;
  final EdgeInsets padding;
  final ValueChanged<String>? onChanged;

  const _HoursField({
    required this.fieldKey,
    required this.controller,
    required this.error,
    required this.modified,
    this.padding = const EdgeInsets.only(right: 12, top: 4, bottom: 4),
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Padding(
      padding: padding,
      child: TextField(
        key: fieldKey,
        controller: controller,
        enabled: onChanged != null,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          suffixText: 'hs',
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
