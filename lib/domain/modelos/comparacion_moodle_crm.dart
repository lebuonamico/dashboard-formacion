import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

/// Horas por categoría de cada fuente para un grupo de colaboradores.
/// Moodle: cursos finalizados en el LMS por su carga horaria (solo Negocio y
/// Blandas). CRM: horas declaradas en cada categoría.
class ComparacionMoodleCrm {
  final Map<TipoCurso, double> moodle;
  final Map<TipoCurso, double> crm;

  const ComparacionMoodleCrm({required this.moodle, required this.crm});

  /// Categorías que existen en las dos fuentes.
  static const comparables = [
    TipoCurso.habilidadesDeNegocio,
    TipoCurso.habilidadesBlandas,
  ];

  factory ComparacionMoodleCrm.desde(List<CumplimientoEmpleado> items) {
    double suma(
      Map<TipoCurso, double> Function(CumplimientoEmpleado) horas,
      TipoCurso tipo,
    ) => items.fold(0, (t, item) => t + (horas(item)[tipo] ?? 0));
    return ComparacionMoodleCrm(
      moodle: {
        for (final tipo in comparables)
          tipo: suma((item) => item.horasValidas, tipo),
      },
      crm: {
        for (final tipo in TipoCurso.values)
          tipo: suma((item) => item.horasDeclaradas, tipo),
      },
    );
  }

  double totalMoodle(Iterable<TipoCurso> tipos) =>
      tipos.fold(0, (t, tipo) => t + (moodle[tipo] ?? 0));

  double totalCrm(Iterable<TipoCurso> tipos) =>
      tipos.fold(0, (t, tipo) => t + (crm[tipo] ?? 0));

  /// Horas que CRM registra de más (o de menos, si es negativa) que Moodle en
  /// las categorías comparables.
  double get diferenciaComparable =>
      totalCrm(comparables) - totalMoodle(comparables);

  /// La diferencia como porcentaje de lo registrado en Moodle; `null` si
  /// Moodle no tiene horas.
  double? get diferenciaPorcentual {
    final moodleComparable = totalMoodle(comparables);
    return moodleComparable == 0
        ? null
        : diferenciaComparable / moodleComparable * 100;
  }

  /// Menos de 0.05 h de diferencia se muestra como que coinciden.
  bool get coinciden => diferenciaComparable.abs() < 0.05;
}
