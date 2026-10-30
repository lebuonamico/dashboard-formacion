import 'package:flutter_riverpod/legacy.dart';

enum PeriodScope {
  monthly('Mensual'),
  annual('Anual');

  final String label;
  const PeriodScope(this.label);
}

final periodScopeProvider = StateProvider<PeriodScope>(
  (ref) => PeriodScope.monthly,
);

final periodMonthFilterProvider = StateProvider<int>(
  (ref) => DateTime.now().month,
);

final periodYearFilterProvider = StateProvider<int>(
  (ref) => DateTime.now().year,
);
