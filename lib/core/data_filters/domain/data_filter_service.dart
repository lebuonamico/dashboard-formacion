import 'package:app_finnegans/core/data_filters/domain/data_filter.dart';

class DataFilterService {
  const DataFilterService();

  /// OR between the values of a dimension, AND between active dimensions.
  bool matches(DataFilterValues selection, FilterRow row) =>
      selection.entries.every(
        (entry) =>
            entry.value.isEmpty || entry.value.contains(row.values[entry.key]),
      );

  DataFilterValues withValues(
    DataFilterValues current,
    String dimension,
    Set<String> values,
  ) => Map.unmodifiable({
    for (final entry in current.entries)
      if (entry.key != dimension) entry.key: entry.value,
    if (values.isNotEmpty) dimension: Set<String>.unmodifiable(values),
  });

  String labelFor(DataFilterOptions options, String value) =>
      options.labels[value] ?? value;

  /// Options of each dimension that stay compatible with the other active
  /// dimensions. A row that fails exactly one dimension still offers its
  /// value for that dimension, so a selection never hides its own siblings.
  Map<String, DataFilterOptions> cascade(
    List<FilterRow> rows,
    DataFilterValues selection, {
    DataFilterLabels selectedLabels = const {},
  }) {
    final active = selection.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    final dimensions = {
      ...rows.expand(
        (row) => row.values.entries
            .where((entry) => entry.value.trim().isNotEmpty)
            .map((entry) => entry.key),
      ),
      ...selection.keys,
    };

    return Map.unmodifiable({
      for (final dimension in dimensions)
        dimension: _options(
          available: rows
              .where((row) => _offersValueFor(row, dimension, active))
              .map((row) => row.values[dimension] ?? '')
              .where((value) => value.trim().isNotEmpty),
          selected: selection[dimension] ?? const {},
          labels: {
            ...?selectedLabels[dimension],
            ..._rowLabels(rows, dimension),
          },
        ),
    });
  }

  bool _offersValueFor(
    FilterRow row,
    String dimension,
    List<MapEntry<String, Set<String>>> active,
  ) {
    final failed = active
        .where((entry) => !entry.value.contains(row.values[entry.key]))
        .map((entry) => entry.key)
        .toList();
    return failed.isEmpty || (failed.length == 1 && failed.single == dimension);
  }

  Map<String, String> _rowLabels(List<FilterRow> rows, String dimension) => {
    for (final row in rows.reversed)
      if (row.labels[dimension] case final label?)
        if ((row.values[dimension] ?? '').isNotEmpty)
          row.values[dimension]!: label,
  };

  DataFilterOptions _options({
    required Iterable<String> available,
    required Set<String> selected,
    required Map<String, String> labels,
  }) {
    String label(String value) => labels[value] ?? value;
    final availableSet = available.toSet();
    final values = {...availableSet, ...selected}.toList()
      ..sort((a, b) {
        final byLabel = label(a).compareTo(label(b));
        return byLabel == 0 ? a.compareTo(b) : byLabel;
      });
    return DataFilterOptions(
      values: List.unmodifiable(values),
      incompatibleValues: Set.unmodifiable(selected.difference(availableSet)),
      labels: Map.unmodifiable(labels),
    );
  }
}
