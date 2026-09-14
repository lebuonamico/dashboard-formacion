import 'package:app_finnegans/domain/modelos/tipo_curso.dart';

enum Seniority {
  trainee('Trainee', negocio: 4, blandas: 4, libres: 0, dictado: 0),
  junior1('Junior 1', negocio: 4, blandas: 4, libres: 0, dictado: 0),
  junior2('Junior 2', negocio: 4, blandas: 4, libres: 0, dictado: 0),
  junior3('Junior 3', negocio: 3, blandas: 4, libres: 1, dictado: 0),
  semisenior1('Semisenior 1', negocio: 3, blandas: 4, libres: 1, dictado: 0),
  semisenior2('Semisenior 2', negocio: 2, blandas: 4, libres: 1, dictado: 1),
  semisenior3('Semisenior 3', negocio: 1, blandas: 4, libres: 1, dictado: 2),
  senior1('Senior 1', negocio: 0, blandas: 2, libres: 2, dictado: 4),
  senior2('Senior 2', negocio: 0, blandas: 2, libres: 2, dictado: 4),
  senior3('Senior 3', negocio: 0, blandas: 2, libres: 2, dictado: 4),
  manager('Manager', negocio: 0, blandas: 0, libres: 8, dictado: 0);

  final String label;
  final double negocio;
  final double blandas;
  final double libres;
  final double dictado;

  const Seniority(
    this.label, {
    required this.negocio,
    required this.blandas,
    required this.libres,
    required this.dictado,
  });

  /// Devuelve la meta de horas para un tipo de curso específico
  double horasRequeridas(TipoCurso tipo) {
    switch (tipo) {
      case TipoCurso.habilidadesDeNegocio:
        return negocio;
      case TipoCurso.habilidadesBlandas:
        return blandas;
      case TipoCurso.libresExploracion:
        return libres;
      case TipoCurso.dictadoCapacitaciones:
        return dictado;
    }
  }

  /// Mapa completo de requerimientos
  Map<TipoCurso, double> get planFormacion => {
    TipoCurso.habilidadesDeNegocio: negocio,
    TipoCurso.habilidadesBlandas: blandas,
    TipoCurso.libresExploracion: libres,
    TipoCurso.dictadoCapacitaciones: dictado,
  };
}