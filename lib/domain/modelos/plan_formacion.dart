import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

/// Horas mensuales requeridas por categoría para cada seniority. Siempre
/// está completo y es válido: el constructor rechaza lo que no lo es.
class PlanFormacion {
  /// Tope por categoría y mes: un error de tipeo (80 en lugar de 8) no pasa
  /// como un objetivo válido.
  static const maximoHorasPorCategoria = 160.0;

  final Map<Seniority, Map<TipoCurso, double>> _horas;

  PlanFormacion(Map<Seniority, Map<TipoCurso, double>> horas)
    : _horas = Map.unmodifiable({
        for (final seniority in Seniority.values)
          seniority: Map<TipoCurso, double>.unmodifiable({
            for (final tipo in TipoCurso.values)
              tipo: _validar(seniority, tipo, horas[seniority]?[tipo]),
          }),
      });

  /// El plan que regía cuando estaba fijo en el código (los valores del enum
  /// [Seniority]). Es el de cualquier mes anterior a la primera versión.
  factory PlanFormacion.porDefecto() => _porDefecto;

  static final _porDefecto = PlanFormacion({
    for (final seniority in Seniority.values)
      seniority: seniority.planFormacion,
  });

  factory PlanFormacion.fromJson(Map<String, dynamic> json) => PlanFormacion({
    for (final seniority in Seniority.values)
      if (json[seniority.name] case final Map<String, dynamic> porTipo)
        seniority: {
          for (final tipo in TipoCurso.values)
            if (porTipo[tipo.name] case final num horas) tipo: horas.toDouble(),
        },
  });

  /// Mensaje de error para un valor de horas, o `null` si es válido. La misma
  /// regla que aplica el constructor, para validar campo por campo en la UI.
  static String? errorHoras(double? horas) {
    if (horas == null || !horas.isFinite) return 'Ingresá un número';
    if (horas < 0) return 'No puede ser negativo';
    if (horas > maximoHorasPorCategoria) {
      return 'Máximo ${maximoHorasPorCategoria.toStringAsFixed(0)} h';
    }
    return null;
  }

  static double _validar(Seniority seniority, TipoCurso tipo, double? horas) {
    if (horas == null) {
      throw FormatException(
        'Al plan le falta ${tipo.label} para ${seniority.label}.',
      );
    }
    final error = errorHoras(horas);
    if (error != null) {
      throw FormatException(
        '${seniority.label}, ${tipo.label}: $error ($horas).',
      );
    }
    return horas;
  }

  Map<TipoCurso, double> horasRequeridas(Seniority seniority) =>
      _horas[seniority]!;

  double total(Seniority seniority) =>
      _horas[seniority]!.values.fold(0.0, (total, horas) => total + horas);

  Map<String, dynamic> toJson() => {
    for (final MapEntry(key: seniority, value: porTipo) in _horas.entries)
      seniority.name: {
        for (final MapEntry(key: tipo, value: horas) in porTipo.entries)
          tipo.name: horas,
      },
  };

  @override
  bool operator ==(Object other) =>
      other is PlanFormacion &&
      Seniority.values.every(
        (seniority) => TipoCurso.values.every(
          (tipo) => _horas[seniority]![tipo] == other._horas[seniority]![tipo],
        ),
      );

  @override
  int get hashCode => Object.hashAll([
    for (final seniority in Seniority.values)
      for (final tipo in TipoCurso.values) _horas[seniority]![tipo],
  ]);
}

/// Un plan y el mes desde el que rige.
class VersionPlanFormacion {
  /// Primer día del mes.
  final DateTime vigenteDesde;
  final PlanFormacion plan;

  VersionPlanFormacion({required DateTime vigenteDesde, required this.plan})
    : vigenteDesde = DateTime(vigenteDesde.year, vigenteDesde.month);

  factory VersionPlanFormacion.fromJson(Map<String, dynamic> json) =>
      VersionPlanFormacion(
        vigenteDesde: DateTime.parse(json['vigenteDesde'].toString()),
        plan: PlanFormacion.fromJson(json['plan'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
    'vigenteDesde': fechaIso(vigenteDesde),
    'plan': plan.toJson(),
  };

  /// `yyyy-mm-dd`, el formato de una columna `date`.
  static String fechaIso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}

/// Las versiones del plan, una por mes como máximo. Cada mes se evalúa con
/// la versión vigente en ese mes, así cambiar el plan no reescribe los meses
/// ya evaluados (el mismo criterio que el historial de la nómina).
class PlanesFormacion {
  /// De la más vieja a la más nueva.
  final List<VersionPlanFormacion> versiones;

  const PlanesFormacion.sinVersiones() : versiones = const [];

  PlanesFormacion(Iterable<VersionPlanFormacion> versiones)
    : versiones = List.unmodifiable(_ordenadas(versiones));

  static List<VersionPlanFormacion> _ordenadas(
    Iterable<VersionPlanFormacion> versiones,
  ) {
    final lista = versiones.toList()
      ..sort((a, b) => a.vigenteDesde.compareTo(b.vigenteDesde));
    for (var i = 1; i < lista.length; i++) {
      if (lista[i].vigenteDesde == lista[i - 1].vigenteDesde) {
        throw FormatException(
          'Hay dos planes de formación que rigen desde '
          '${VersionPlanFormacion.fechaIso(lista[i].vigenteDesde)}.',
        );
      }
    }
    return lista;
  }

  /// La versión que rige en ese mes, o `null` si es anterior a la primera
  /// (entonces rige el plan por defecto).
  VersionPlanFormacion? versionVigenteEn(int anio, int mes) {
    final inicio = DateTime(anio, mes);
    for (final version in versiones.reversed) {
      if (!version.vigenteDesde.isAfter(inicio)) return version;
    }
    return null;
  }

  PlanFormacion vigenteEn(int anio, int mes) =>
      versionVigenteEn(anio, mes)?.plan ?? PlanFormacion.porDefecto();

  PlanFormacion get actual {
    final hoy = DateTime.now();
    return vigenteEn(hoy.year, hoy.month);
  }

  /// Suma de los 12 objetivos mensuales del año, cada uno con su versión.
  Map<TipoCurso, double> requeridasDelAnio(Seniority seniority, int anio) {
    final total = {for (final tipo in TipoCurso.values) tipo: 0.0};
    for (var mes = 1; mes <= 12; mes++) {
      final plan = vigenteEn(anio, mes).horasRequeridas(seniority);
      for (final tipo in TipoCurso.values) {
        total[tipo] = total[tipo]! + plan[tipo]!;
      }
    }
    return total;
  }

  /// Agrega la versión, o reemplaza la que rige desde ese mismo mes.
  PlanesFormacion conVersion(VersionPlanFormacion version) => PlanesFormacion([
    for (final actual in versiones)
      if (actual.vigenteDesde != version.vigenteDesde) actual,
    version,
  ]);
}
