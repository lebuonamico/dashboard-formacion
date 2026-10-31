import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/period/domain/optional_period.dart';
import 'package:app_finnegans/core/period/presentation/period_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/core/period/domain/optional_period.dart';

typedef OptionalPeriodProvider =
    NotifierProvider<OptionalPeriodNotifier, OptionalPeriod>;

class OptionalPeriodNotifier extends Notifier<OptionalPeriod> {
  @override
  OptionalPeriod build() => const OptionalPeriod();

  void setYear(int? year) =>
      state = OptionalPeriod(year: year, month: state.month);

  void setMonth(int? month) =>
      state = OptionalPeriod(year: state.year, month: month);

  void clear() => state = const OptionalPeriod();
}

class OptionalYearFilter extends ConsumerWidget {
  final OptionalPeriodProvider provider;
  final List<int> availableYears;
  final String hint;
  final double width;

  const OptionalYearFilter({
    super.key,
    required this.provider,
    required this.availableYears,
    this.hint = 'Todos los años',
    this.width = 260,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(provider).year;
    final years = {...availableYears, ?year}.toList()
      ..sort((a, b) => b.compareTo(a));
    return FilterDropdown<int?>(
      value: year,
      hint: hint,
      icon: Icons.event_outlined,
      width: width,
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos los años'),
        ),
        for (final option in years)
          DropdownMenuItem<int?>(value: option, child: Text('$option')),
      ],
      onChanged: ref.read(provider.notifier).setYear,
    );
  }
}

class OptionalMonthFilter extends ConsumerWidget {
  final OptionalPeriodProvider provider;
  final String hint;
  final double width;

  const OptionalMonthFilter({
    super.key,
    required this.provider,
    this.hint = 'Todos los meses',
    this.width = 260,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilterDropdown<int?>(
    value: ref.watch(provider).month,
    hint: hint,
    icon: Icons.calendar_month_outlined,
    width: width,
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('Todos los meses')),
      for (var month = 1; month <= 12; month++)
        DropdownMenuItem<int?>(value: month, child: Text(monthName(month))),
    ],
    onChanged: ref.read(provider.notifier).setMonth,
  );
}
