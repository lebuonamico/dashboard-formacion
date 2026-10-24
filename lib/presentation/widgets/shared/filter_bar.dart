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
      padding: const EdgeInsets.all(16),
      decoration: context.panel(),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final field in fields)
                SizedBox(
                  width: constraints.maxWidth < 600
                      ? constraints.maxWidth
                      : field.width,
                  child: field,
                ),
              OutlinedButton.icon(
                onPressed: active
                    ? () {
                        if (scope != null) {
                          ref
                              .read(
                                dataFilterSelectionProvider(scope!).notifier,
                              )
                              .clear();
                        }
                        onClear();
                      }
                    : null,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Limpiar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
