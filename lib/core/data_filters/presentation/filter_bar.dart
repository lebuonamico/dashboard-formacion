import 'dart:math' as math;

import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Independent filters for a list. Each menu has its own search.
///
/// Below 840 px, when the filters do not fit in a row, the bar becomes a
/// "Filtros (n)" button that opens them stacked in a bottom sheet. The sheet
/// is another route, so [extraFilters] must read their state from providers,
/// as the screens' do.
class FilterBar extends ConsumerStatefulWidget {
  final DataFilterScope scope;
  final AsyncValue<List<FilterRow>> rows;
  final List<Widget> extraFilters;

  /// How many of [extraFilters] have a value: they count in "Filtros (n)" and
  /// enable "Limpiar".
  final int activeExtraFilters;
  final VoidCallback? onClearExtraFilters;

  const FilterBar({
    super.key,
    required this.scope,
    required this.rows,
    this.extraFilters = const [],
    this.activeExtraFilters = 0,
    this.onClearExtraFilters,
  });

  @override
  ConsumerState<FilterBar> createState() => _FilterBarState();
}

/// The fields of a [FilterBar], how many are active and how to clear them.
typedef _Filters = ({List<Widget> fields, int active, VoidCallback? onClear});

_Filters _filtersOf(WidgetRef ref, FilterBar bar) {
  final selection = ref.watch(dataFilterSelectionProvider(bar.scope));
  final service = ref.watch(dataFilterServiceProvider);
  final rowsReady = bar.rows.hasValue && !bar.rows.hasError;
  final options = service.cascade(
    bar.rows.value ?? const [],
    selection.values,
    selectedLabels: selection.labels,
  );
  final active =
      selection.values.values.where((values) => values.isNotEmpty).length +
      bar.activeExtraFilters;

  return (
    fields: [
      for (final MapEntry(key: dimension, value: dimensionOptions)
          in options.entries)
        _DimensionFilter(
          key: ValueKey('${bar.scope.name}:$dimension'),
          dimension: dimension,
          options: dimensionOptions,
          selected: selection.values[dimension] ?? const {},
          enabled: rowsReady,
          onSelectionChanged: (values) => ref
              .read(dataFilterSelectionProvider(bar.scope).notifier)
              .select(dimension, values, labels: dimensionOptions.labels),
        ),
      ...bar.extraFilters,
    ],
    active: active,
    onClear: active > 0
        ? () {
            ref.read(dataFilterSelectionProvider(bar.scope).notifier).clear();
            bar.onClearExtraFilters?.call();
          }
        : null,
  );
}

/// Larger text needs wider fields and taller controls.
double _textScaleOf(BuildContext context) =>
    math.max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14);

class _FilterBarState extends ConsumerState<FilterBar> {
  /// The sheet follows the latest configuration through this notifier.
  late final ValueNotifier<FilterBar> _latest;

  @override
  void initState() {
    super.initState();
    _latest = ValueNotifier(widget);
  }

  @override
  void didUpdateWidget(FilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The sheet cannot be marked dirty while this subtree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _latest.value = widget;
    });
  }

  @override
  void dispose() {
    _latest.dispose();
    super.dispose();
  }

  void _openSheet() => showModalBottomSheet<void>(
    context: context,
    // Above the shell, so it also covers the assistant button.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: (_) => ValueListenableBuilder<FilterBar>(
      valueListenable: _latest,
      builder: (_, bar, _) => _FilterSheet(bar: bar),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final filters = _filtersOf(ref, widget);
    final row = _FilterBarLayout(
      fields: filters.fields,
      onClear: filters.onClear,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: context.panel(),
      child: context.windowSize == WindowSize.expanded
          ? row
          : LayoutBuilder(
              builder: (context, constraints) =>
                  _FilterBarLayout.fits(
                    filters.fields.length,
                    constraints.maxWidth,
                    _textScaleOf(context),
                  )
                  ? row
                  : _FilterSheetButton(
                      active: filters.active,
                      onOpen: _openSheet,
                      onClear: filters.onClear,
                    ),
            ),
    );
  }
}

class _DimensionFilter extends StatelessWidget {
  final String dimension;
  final DataFilterOptions options;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<Set<String>> onSelectionChanged;

  const _DimensionFilter({
    super.key,
    required this.dimension,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasEntity = filterEntitySubtitle(dimension, '') != null;
    return FilterDropdown<String>.multiple(
      selectedValues: selected,
      incompatibleValues: enabled ? options.incompatibleValues : const {},
      itemTitleBuilder: _entityTitle,
      itemSubtitleBuilder: hasEntity
          ? (value) => filterEntitySubtitle(dimension, value)
          : null,
      hint: dimension,
      icon: Icons.filter_alt_outlined,
      items: [
        for (final value in options.values)
          DropdownMenuItem(
            value: value,
            child: Text(options.labels[value] ?? value),
          ),
      ],
      onSelectionChanged: enabled ? onSelectionChanged : null,
    );
  }

  String _entityTitle(String value) {
    final label = options.labels[value] ?? value;
    final suffix = ' — ${filterEntitySubtitle(dimension, value)}';
    return label.endsWith(suffix)
        ? label.substring(0, label.length - suffix.length)
        : label;
  }
}

/// Below 840 px, when the row does not fit: the button that opens the sheet
/// and "Limpiar".
class _FilterSheetButton extends StatelessWidget {
  final int active;
  final VoidCallback onOpen;
  final VoidCallback? onClear;

  const _FilterSheetButton({
    required this.active,
    required this.onOpen,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(active == 0 ? 'Filtros' : 'Filtros ($active)');
    const icon = Icon(Icons.tune, size: 18);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: active == 0
                  ? OutlinedButton.icon(
                      key: const Key('filter_sheet_button'),
                      onPressed: onOpen,
                      icon: icon,
                      label: label,
                    )
                  : FilledButton.tonalIcon(
                      key: const Key('filter_sheet_button'),
                      onPressed: onOpen,
                      icon: icon,
                      label: label,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.outlined(
            onPressed: onClear,
            tooltip: 'Limpiar',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

/// The filters stacked, inside the bottom sheet. They apply as they change;
/// "Listo" only closes.
class _FilterSheet extends ConsumerWidget {
  final FilterBar bar;

  const _FilterSheet({required this.bar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = _filtersOf(ref, bar);
    final controlHeight = 56.0 * _textScaleOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        8 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtros',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final field in filters.fields)
                    Padding(
                      // Room for the floating label.
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(height: controlHeight, child: field),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                onPressed: filters.onClear,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpiar'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Listo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBarLayout extends StatefulWidget {
  static const _spacing = 12.0;
  static const _minFieldWidth = 200.0;

  final List<Widget> fields;
  final VoidCallback? onClear;

  const _FilterBarLayout({required this.fields, required this.onClear});

  /// Whether [count] fields fit in [width] without scrolling sideways, next to
  /// the "Limpiar" button.
  static bool fits(int count, double width, double textScale) {
    final clearWidth = width < 400 * textScale ? 48.0 : 120.0;
    return count * _minFieldWidth * textScale + count * _spacing + clearWidth <=
        width;
  }

  @override
  State<_FilterBarLayout> createState() => _FilterBarLayoutState();
}

class _FilterBarLayoutState extends State<_FilterBarLayout> {
  static const _spacing = _FilterBarLayout._spacing;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = _textScaleOf(context);
    final controlHeight = 56.0 * textScale;

    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = widget.fields.length;
                if (count == 0) {
                  return SizedBox(height: controlHeight + 16);
                }
                final minWidth =
                    count * _FilterBarLayout._minFieldWidth * textScale +
                    (count - 1) * _spacing;
                final needsScroll = minWidth > constraints.maxWidth;

                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: needsScroll,
                    interactive: true,
                    thickness: 6,
                    radius: const Radius.circular(3),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      primary: false,
                      scrollDirection: Axis.horizontal,
                      // Room for the floating label and the scrollbar.
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: math.max(minWidth, constraints.maxWidth),
                        height: controlHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < count; i++) ...[
                              if (i > 0) const SizedBox(width: _spacing),
                              Expanded(child: widget.fields[i]),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: _spacing),
          SizedBox(
            height: controlHeight,
            child: constraints.maxWidth < 400 * textScale
                ? IconButton.outlined(
                    onPressed: widget.onClear,
                    tooltip: 'Limpiar',
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  )
                : OutlinedButton.icon(
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Limpiar'),
                  ),
          ),
        ],
      ),
    );
  }
}
