import 'package:flutter_riverpod/legacy.dart';

enum AlcancePeriodo {
  mensual('Mensual'),
  anual('Anual');

  final String label;
  const AlcancePeriodo(this.label);
}

final alcancePeriodoProvider = StateProvider<AlcancePeriodo>(
  (ref) => AlcancePeriodo.mensual,
);

final filtroMesPeriodoProvider = StateProvider<int>(
  (ref) => DateTime.now().month,
);

final filtroAnioPeriodoProvider = StateProvider<int>(
  (ref) => DateTime.now().year,
);

final soloRegistrosCargadosPeriodoProvider = StateProvider<bool>(
  (ref) => false,
);
