import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/training_plan/domain/training_plan.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';
import 'package:app_finnegans/features/courses/domain/course_category.dart';
import 'package:app_finnegans/features/training_plan/presentation/providers/training_plan_providers.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:app_finnegans/features/employees/presentation/widgets/seniority_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/courses/presentation/course_category_labels.dart';

/// Edita las horas mensuales requeridas por categoría para cada seniority.
/// Cada guardado es una versión que rige desde el mes elegido: los meses
/// anteriores conservan el plan que tenían.
class TrainingPlanEditor extends ConsumerStatefulWidget {
  const TrainingPlanEditor({super.key});

  @override
  ConsumerState<TrainingPlanEditor> createState() => _TrainingPlanEditorState();
}

class _TrainingPlanEditorState extends ConsumerState<TrainingPlanEditor> {
  static const _widthSeniority = 170.0;
  static const _hoursWidth = 104.0;
  static const _widthTotal = 90.0;

  final _controllers = {
    for (final seniority in Seniority.values)
      for (final type in CourseCategory.values)
        (seniority, type): TextEditingController(),
  };

  late int _year;
  late int _month;
  TrainingPlanHistory? _plans;

  /// Plan vigente en el mes elegido: contra él se marcan los cambios.
  TrainingPlan? _base;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _year = today.year;
    _month = today.month;
    // El formulario se carga cada vez que cambian los planes guardados (al
    // abrir la pantalla y después de guardar).
    ref.listenManual(trainingPlanHistoryProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        _plans = value;
        _load(value.currentIn(_year, _month));
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Pone el plan en el formulario y lo toma como base de los cambios.
  void _load(TrainingPlan plan, {bool asBase = true}) {
    if (asBase) _base = plan;
    for (final MapEntry(key: (seniority, type), value: controller)
        in _controllers.entries) {
      controller.text = _text(plan.requiredHours(seniority)[type]!);
    }
  }

  static String _text(double hours) => hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toString().replaceAll('.', ',');

  /// Acepta coma decimal. Se redondea a 2 decimales, como la base.
  static double? _hours(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    return value == null ? null : (value * 100).round() / 100;
  }

  double? _value(Seniority seniority, CourseCategory type) =>
      _hours(_controllers[(seniority, type)]!.text);

  /// El plan del formulario, o `null` si algún campo es inválido.
  TrainingPlan? get _editedPlan {
    final hours = <Seniority, Map<CourseCategory, double>>{};
    for (final seniority in Seniority.values) {
      for (final type in CourseCategory.values) {
        final value = _value(seniority, type);
        if (TrainingPlan.hoursError(value) != null) return null;
        (hours[seniority] ??= {})[type] = value!;
      }
    }
    return TrainingPlan(hours);
  }

  bool get _hasChanges => _editedPlan != _base;

  bool get _pastMonth {
    final today = DateTime.now();
    return DateTime(_year, _month).isBefore(DateTime(today.year, today.month));
  }

  Future<void> _chooseMonth(int year, int month) async {
    if (year == _year && month == _month) return;
    if (!await _confirmDiscard()) return;
    setState(() {
      _year = year;
      _month = month;
      _load(_plans!.currentIn(year, month));
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Hay cambios sin guardar en el plan. ¿Querés descartarlos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save(TrainingPlan plan) async {
    final validity = '${monthName(_month)} $_year';
    setState(() => _saving = true);
    try {
      await ref
          .read(trainingPlanRepositoryProvider)
          .saveVersion(
            TrainingPlanVersion(validFrom: DateTime(_year, _month), plan: plan),
          );
      // Recalcula todo el cumplimiento y recarga el formulario.
      ref.invalidate(trainingPlanHistoryProvider);
      await ref.read(trainingPlanHistoryProvider.future);
      if (mounted) {
        showAppSnackBar(context, 'Plan guardado: rige desde $validity.');
      }
    } on FormatException catch (error) {
      if (mounted) showAppSnackBar(context, error.message);
    } on Object catch (error) {
      if (mounted) {
        showAppSnackBar(context, 'No se pudo guardar el plan: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(trainingPlanHistoryProvider);
    final plans = _plans;
    if (plansAsync.hasError && plans == null) {
      return Text(
        'No se pudo cargar el plan de formación: ${plansAsync.error}',
        style: TextStyle(color: context.colors.danger.text),
      );
    }
    if (plans == null || _base == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final editedPlan = _editedPlan;
    final hasChanges = editedPlan != _base;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidity(plans),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildTable(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            TextButton.icon(
              key: const Key('plan_restaurar'),
              onPressed: _saving
                  ? null
                  : () => setState(
                      () => _load(TrainingPlan.byDefault(), asBase: false),
                    ),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restaurar valores por defecto'),
            ),
            TextButton(
              key: const Key('plan_descartar'),
              onPressed: hasChanges && !_saving
                  ? () => setState(() => _load(_base!))
                  : null,
              child: const Text('Descartar cambios'),
            ),
            FilledButton.icon(
              key: const Key('plan_guardar'),
              onPressed: editedPlan != null && hasChanges && !_saving
                  ? () => _save(editedPlan)
                  : null,
              icon: _saving
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

  Widget _buildValidity(TrainingPlanHistory plans) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final today = DateTime.now();
    final firstYear = [
      today.year - 1,
      ...plans.versions.map((version) => version.validFrom.year),
    ].reduce((a, b) => a < b ? a : b);
    final years = [for (var a = firstYear; a <= today.year + 1; a++) a];
    final current = plans.currentVersionIn(_year, _month);
    final next = plans.versions
        .where((version) => version.validFrom.isAfter(DateTime(_year, _month)))
        .firstOrNull;
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
              value: _month,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(monthName(m))),
              ],
              onChanged: _saving
                  ? null
                  : (month) =>
                        month == null ? null : _chooseMonth(_year, month),
            ),
            DropdownButton<int>(
              key: const Key('plan_anio'),
              value: _year,
              items: [
                for (final year in years)
                  DropdownMenuItem(value: year, child: Text('$year')),
              ],
              onChanged: _saving
                  ? null
                  : (year) => year == null ? null : _chooseMonth(year, _month),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          current == null
              ? 'Hasta ahora ese mes usa los valores por defecto.'
              : current.validFrom == DateTime(_year, _month)
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
        if (_pastMonth)
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
                    'evaluados desde ${monthName(_month)} $_year.',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.warning.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (plans.versions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final version in plans.versions)
                ActionChip(
                  label: Text('Desde ${_monthLabel(version.validFrom)}'),
                  onPressed: _saving
                      ? null
                      : () => _chooseMonth(
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

  static String _monthLabel(DateTime date) =>
      '${monthName(date.month).toLowerCase()} ${date.year}';

  Widget _buildTable() {
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
            for (final type in CourseCategory.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 12),
                child: Tooltip(
                  message: type.label,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.category(type).text,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(type.shortLabel, style: headerStyle),
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
        for (final seniority in Seniority.values) _row(seniority),
      ],
    );
  }

  TableRow _row(Seniority seniority) {
    final cs = context.colorScheme;
    final values = [
      for (final type in CourseCategory.values) _value(seniority, type),
    ];
    // Con un campo inválido no hay total que mostrar.
    final total =
        values.every((value) => TrainingPlan.hoursError(value) == null)
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
        for (final type in CourseCategory.values) _field(seniority, type),
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
              total == null ? '—' : '${_text(total)} h',
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

  Widget _field(Seniority seniority, CourseCategory type) {
    final cs = context.colorScheme;
    final value = _value(seniority, type);
    final error = TrainingPlan.hoursError(value);
    final modified =
        error == null && value != _base!.requiredHours(seniority)[type];

    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
      child: TextField(
        key: Key('plan_${seniority.name}_${type.name}'),
        controller: _controllers[(seniority, type)],
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.end,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          suffixText: 'h',
          errorText: error,
          errorMaxLines: 2,
          filled: modified,
          fillColor: cs.primaryContainer.withValues(alpha: 0.45),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
