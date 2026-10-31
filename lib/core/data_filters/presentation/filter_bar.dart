import 'dart:math' as math;

import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dimensions.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtros independientes del listado. La búsqueda vive dentro de cada menú.
class FilterBar extends ConsumerWidget {
  final DataFilterScope scope;
  final AsyncValue<List<FilterRow>> rows;
  final List<Widget> extraFilters;
  final bool hasActiveExtraFilters;
  final VoidCallback? onClearExtraFilters;

  const FilterBar({
    super.key,
    required this.scope,
    required this.rows,
    this.extraFilters = const [],
    this.hasActiveExtraFilters = false,
    this.onClearExtraFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(dataFilterSelectionProvider(scope));
    final selectionNotifier = ref.read(
      dataFilterSelectionProvider(scope).notifier,
    );
    final service = ref.watch(dataFilterServiceProvider);
    final rowsReady = rows.hasValue && !rows.hasError;
    final options = service.cascade(
      rows.value ?? const [],
      selection.values,
      selectedLabels: selection.labels,
    );
    final isActive =
        hasActiveExtraFilters ||
        selection.values.values.any((values) => values.isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: context.panel(),
      child: _FilterBarLayout(
        fields: [
          for (final MapEntry(key: dimension, value: dimensionOptions)
              in options.entries)
            _DimensionFilter(
              key: ValueKey('${scope.name}:$dimension'),
              dimension: dimension,
              options: dimensionOptions,
              selected: selection.values[dimension] ?? const {},
              enabled: rowsReady,
              onSelectionChanged: (values) => selectionNotifier.select(
                dimension,
                values,
                labels: dimensionOptions.labels,
              ),
            ),
          ...extraFilters,
        ],
        onClear: isActive
            ? () {
                selectionNotifier.clear();
                onClearExtraFilters?.call();
              }
            : null,
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

class _FilterBarLayout extends StatefulWidget {
  final List<Widget> fields;
  final VoidCallback? onClear;

  const _FilterBarLayout({required this.fields, required this.onClear});

  @override
  State<_FilterBarLayout> createState() => _FilterBarLayoutState();
}

class _FilterBarLayoutState extends State<_FilterBarLayout> {
  static const _spacing = 12.0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
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
                    count * 200.0 * textScale + (count - 1) * _spacing;
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
                      // Espacio para la etiqueta flotante y la barra de scroll.
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
