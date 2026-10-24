import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/data_filters_provider.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String? _entitySubtitle(String dimension, String value) =>
    dimension == personaFilterDimension
    ? 'Legajo $value'
    : dimension == cursoFilterDimension
    ? 'ID $value'
    : null;

String _entityTitle(String dimension, String value, DataFilterOptions options) {
  final label = options.labelFor(value);
  final suffix = ' — ${_entitySubtitle(dimension, value)}';
  return label.endsWith(suffix)
      ? label.substring(0, label.length - suffix.length)
      : label;
}

/// Filtros independientes del listado. La búsqueda vive dentro de cada menú.
class FilterBar extends ConsumerWidget {
  final String? scope;
  final List<FilterRow>? rows;
  final DataFilterValues selection;
  final void Function(String dimension, Set<String> values)? onSelectionChanged;
  final List<FilterDropdown<Object?>> filters;
  final bool hasActiveFilters;
  final VoidCallback onClear;

  const FilterBar({
    super.key,
    this.scope,
    this.rows,
    this.selection = const {},
    this.onSelectionChanged,
    required this.hasActiveFilters,
    required this.onClear,
    this.filters = const [],
    // Compatibilidad de construcción con consumidores anteriores; las pantallas
    // actuales usan dimensiones y búsqueda exclusivamente dentro del menú.
    @Deprecated('Usar scope y filtros de selección') String? searchHint,
    @Deprecated('Usar scope y filtros de selección') String? searchText,
    @Deprecated('Usar scope y filtros de selección')
    ValueChanged<String>? onSearch,
  }) : assert(scope == null || rows == null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSelection = scope == null
        ? selection
        : ref.watch(dataFilterSelectionProvider(scope!));
    final optionsAsync = scope == null
        ? AsyncValue.data(
            cascadeFilterOptions(rows ?? const [], activeSelection),
          )
        : ref.watch(dataFilterOptionsProvider(scope!));
    final options =
        optionsAsync.value ??
        cascadeFilterOptions(
          const [],
          activeSelection,
          selectedLabels: scope == null
              ? const {}
              : ref
                    .read(dataFilterSelectionProvider(scope!).notifier)
                    .selectedLabels,
        );
    final fields = <FilterDropdown<Object?>>[
      for (final entry in options.entries)
        FilterDropdown<String>.multiple(
          key: ValueKey('$scope:${entry.key}'),
          selectedValues: activeSelection[entry.key] ?? const {},
          incompatibleValues: optionsAsync.isLoading || optionsAsync.hasError
              ? const {}
              : entry.value.incompatibleValues,
          itemTitleBuilder: (value) =>
              _entityTitle(entry.key, value, entry.value),
          itemSubtitleBuilder:
              entry.key == personaFilterDimension ||
                  entry.key == cursoFilterDimension
              ? (value) => _entitySubtitle(entry.key, value)
              : null,
          hint: entry.key,
          icon: Icons.filter_alt_outlined,
          items: [
            for (final value in entry.value.values)
              DropdownMenuItem(
                value: value,
                child: Text(entry.value.labelFor(value)),
              ),
          ],
          onSelectionChanged: optionsAsync.isLoading || optionsAsync.hasError
              ? null
              : (values) {
                  if (scope == null) {
                    onSelectionChanged?.call(entry.key, values);
                  } else {
                    ref
                        .read(dataFilterSelectionProvider(scope!).notifier)
                        .select(entry.key, values, labels: entry.value.labels);
                  }
                },
        ),
      ...filters,
    ];
    final active =
        hasActiveFilters ||
        activeSelection.values.any((values) => values.isNotEmpty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: context.panel(),
      child: _FilterBarLayout(
        fields: fields,
        onClear: active
            ? () {
                if (scope != null) {
                  ref
                      .read(dataFilterSelectionProvider(scope!).notifier)
                      .clear();
                }
                onClear();
              }
            : null,
      ),
    );
  }
}

class _FilterBarLayout extends StatefulWidget {
  final List<FilterDropdown<Object?>> fields;
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
