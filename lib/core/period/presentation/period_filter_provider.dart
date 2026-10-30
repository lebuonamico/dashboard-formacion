import 'package:app_finnegans/core/period/domain/period_filter.dart';
import 'package:app_finnegans/core/period/domain/period_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:app_finnegans/core/period/domain/period_filter.dart';

final periodServiceProvider = Provider<PeriodService>(
  (ref) => const PeriodService(),
);

final periodFilterProvider =
    NotifierProvider<PeriodFilterNotifier, PeriodFilter>(
      PeriodFilterNotifier.new,
    );

class PeriodFilterNotifier extends Notifier<PeriodFilter> {
  final PeriodFilter? _initial;

  PeriodFilterNotifier([this._initial]);

  @override
  PeriodFilter build() {
    final now = DateTime.now();
    return _initial ??
        PeriodFilter(
          scope: PeriodScope.monthly,
          month: now.month,
          year: now.year,
        );
  }

  void setScope(PeriodScope scope) => state = state.copyWith(scope: scope);

  void setMonth(int month) => state = state.copyWith(month: month);

  void setYear(int year) => state = state.copyWith(year: year);
}
