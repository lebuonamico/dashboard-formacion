import 'package:app_finnegans/core/data_filters/domain/data_filter.dart';
import 'package:app_finnegans/core/data_filters/domain/data_filter_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/core/data_filters/domain/data_filter.dart';

final dataFilterServiceProvider = Provider<DataFilterService>(
  (ref) => const DataFilterService(),
);

class DataFilterSelection {
  final DataFilterValues values;
  final DataFilterLabels labels;

  const DataFilterSelection({this.values = const {}, this.labels = const {}});

  DataFilterSelection copyWith({
    DataFilterValues? values,
    DataFilterLabels? labels,
  }) => DataFilterSelection(
    values: values ?? this.values,
    labels: labels ?? this.labels,
  );
}

final dataFilterSelectionProvider =
    NotifierProvider.family<
      DataFilterSelectionNotifier,
      DataFilterSelection,
      DataFilterScope
    >(DataFilterSelectionNotifier.new);

class DataFilterSelectionNotifier extends Notifier<DataFilterSelection> {
  final DataFilterScope scope;

  DataFilterSelectionNotifier(this.scope);

  @override
  DataFilterSelection build() => const DataFilterSelection();

  void select(
    String dimension,
    Set<String> values, {
    Map<String, String> labels = const {},
  }) {
    final service = ref.read(dataFilterServiceProvider);
    state = state.copyWith(
      values: service.withValues(state.values, dimension, values),
      labels: Map.unmodifiable({
        for (final entry in state.labels.entries)
          if (entry.key != dimension) entry.key: entry.value,
        if (values.isNotEmpty)
          dimension: Map<String, String>.unmodifiable({
            for (final value in values)
              value: labels[value] ?? state.labels[dimension]?[value] ?? value,
          }),
      }),
    );
  }

  void clear() => state = const DataFilterSelection();
}
