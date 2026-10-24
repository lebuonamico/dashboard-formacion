import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _negocio = TipoCurso.habilidadesDeNegocio;
const _blandas = TipoCurso.habilidadesBlandas;

/// Cumplimiento de un mes de un colaborador: [horas] válidas sin tope y
/// [requeridas] por categoría.
CumplimientoEmpleado _mes(
  Map<TipoCurso, double> horas,
  Map<TipoCurso, double> requeridas, {
  String legajo = '1',
}) {
  return CumplimientoEmpleado(
    empleado: Empleado(
      legajo: legajo,
      nombre: 'Ana',
      apellido: 'Pérez',
      seniority: Seniority.senior1,
      area: 'SERVICIOS',
      mail: '$legajo@finnegans.com',
      equipo: 'SOPORTE',
    ),
    horasValidas: horas,
    horasDeclaradas: horas,
    horasRequeridas: requeridas,
  );
}

/// Un mes con una sola categoría (Negocio).
CumplimientoEmpleado _c(double horas, {double objetivo = 8, String id = '1'}) =>
    _mes({_negocio: horas}, {_negocio: objetivo}, legajo: id);

void main() {
  const service = ProyeccionService();

  test('Quien recupera un mes flojo con uno fuerte llega', () {
    // Noviembre 0 de 4 y diciembre 8 de 4: 8 de 8 en el año.
    final proyeccion = service.calcular(
      porMes: {
        11: [_c(0, objetivo: 4)],
        12: [_c(8, objetivo: 4)],
      },
      mesCorte: 12,
    )!;

    expect(proyeccion.meta, 8);
    expect(proyeccion.proyeccion, 8);
    expect(proyeccion.llegan, 1);
    expect(proyeccion.estado, EstadoProyeccion.enCamino);
  });

  test('Las horas no se prestan entre colaboradores', () {
    final proyeccion = service.calcular(
      porMes: {
        12: [_c(16), _c(0, id: '2')],
      },
      mesCorte: 12,
    )!;

    // El excedente del primero no cubre al segundo: (8 + 0) / 2.
    expect(proyeccion.proyeccion, 4);
    expect(proyeccion.meta, 8);
    expect(proyeccion.porcentaje, 50);
    expect(proyeccion.llegan, 1);
    expect(proyeccion.colaboradores, 2);
    expect(proyeccion.estado, EstadoProyeccion.enRiesgo);
  });

  test('El excedente de una categoría no cubre otra', () {
    final proyeccion = service.calcular(
      porMes: {
        12: [
          _mes({_negocio: 10, _blandas: 0}, {_negocio: 4, _blandas: 4}),
        ],
      },
      mesCorte: 12,
    )!;

    expect(proyeccion.proyeccion, 4);
    expect(proyeccion.meta, 8);
    expect(proyeccion.llegan, 0);
  });

  test('Una tendencia creciente proyecta más que un ritmo plano', () {
    final creciente = service.calcular(
      porMes: {
        7: [_c(2)],
        8: [_c(4)],
        9: [_c(6)],
      },
      mesCorte: 9,
    )!;
    final plano = service.calcular(
      porMes: {
        7: [_c(4)],
        8: [_c(4)],
        9: [_c(4)],
      },
      mesCorte: 9,
    )!;

    // Meta: 3 meses con datos + 3 que faltan, a 8 h.
    expect(creciente.meta, 48);
    // 12 acumuladas + 8, 10 y 12 de la tendencia.
    expect(creciente.proyeccion, closeTo(42, 1e-9));
    expect(creciente.estado, EstadoProyeccion.alcanzable);
    expect(plano.proyeccion, closeTo(24, 1e-9));
    expect(plano.estado, EstadoProyeccion.enRiesgo);
    expect(plano.ajuste, closeTo(8, 1e-9));
  });

  test('Una tendencia decreciente nunca resta horas', () {
    final proyeccion = service.calcular(
      porMes: {
        7: [_c(6)],
        8: [_c(4)],
        9: [_c(2)],
      },
      mesCorte: 9,
    )!;

    // La tendencia da 0, -2 y -4: se toman como 0.
    expect(proyeccion.proyeccion, closeTo(12, 1e-9));
  });

  test('Los meses sin datos de nadie no cuentan', () {
    final proyeccion = service.calcular(
      porMes: {
        9: [_c(8)],
      },
      mesCorte: 9,
    )!;

    // Solo septiembre y los 3 meses que faltan, a ritmo plano.
    expect(proyeccion.meta, 32);
    expect(proyeccion.proyeccion, 32);
    expect(proyeccion.estado, EstadoProyeccion.enCamino);
  });

  test('Un mes con datos sin horas del colaborador cuenta como 0', () {
    final proyeccion = service.calcular(
      porMes: {
        8: [_c(0)],
        9: [_c(8)],
      },
      mesCorte: 9,
    )!;

    expect(proyeccion.acumulado, 8);
    expect(proyeccion.meta, 40);
  });

  test('El cumplimiento del mes usa el tope y se compara con el anterior', () {
    final proyeccion = service.calcular(
      porMes: {
        8: [_c(6), _c(8, id: '2')],
        9: [_c(7), _c(12, id: '2')],
      },
      mesCorte: 9,
    )!;

    // Las 12 h del segundo topean en 8 para el mes.
    expect(proyeccion.ritmoReciente, 7.5);
    expect(proyeccion.ritmoMesAnterior, 7);
    expect(proyeccion.variacion, 0.5);
    expect(proyeccion.cumplimientoMes, closeTo(93.75, 1e-9));
  });

  test('Sin mes anterior con datos no hay variación', () {
    final proyeccion = service.calcular(
      porMes: {
        9: [_c(8)],
      },
      mesCorte: 9,
    )!;

    expect(proyeccion.ritmoMesAnterior, isNull);
    expect(proyeccion.variacion, isNull);
  });

  group('Por colaborador', () {
    test('Dice cuánto le falta en cada habilidad, la mayor primero', () {
      // Diciembre: 1 de 4 en Negocio, 2 de 4 en Blandas.
      final empleado = service
          .proyectarEmpleados(
            porMes: {
              12: [
                _mes({_negocio: 1, _blandas: 2}, {_negocio: 4, _blandas: 4}),
              ],
            },
            mesCorte: 12,
          )
          .single;

      expect(empleado.llega, isFalse);
      expect(empleado.faltantes.map((c) => c.tipo), [_negocio, _blandas]);
      expect(empleado.faltantes.map((c) => c.falta), [3, 2]);
    });

    test('Solo incluye las habilidades que pide su seniority', () {
      final empleado = service
          .proyectarEmpleados(
            porMes: {
              12: [
                _mes({_negocio: 5, _blandas: 3}, {_negocio: 4, _blandas: 0}),
              ],
            },
            mesCorte: 12,
          )
          .single;

      expect(empleado.categorias.map((c) => c.tipo), [_negocio]);
      expect(empleado.llega, isTrue);
      expect(empleado.faltantes, isEmpty);
      expect(empleado.estado, EstadoProyeccion.enCamino);
    });

    test('Usa todo su historial y proyecta los meses que faltan', () {
      final empleado = service
          .proyectarEmpleados(
            porMes: {
              8: [_c(4), _c(8, id: '2')],
              9: [_c(4), _c(8, id: '2')],
            },
            mesCorte: 9,
          )
          .firstWhere((e) => e.legajo == '1');
      final negocio = empleado.categorias.single;

      expect(negocio.acumulado, 8);
      expect(negocio.meta, 40);
      // Ritmo plano de 4 h en los 3 meses que faltan.
      expect(negocio.proyectado, closeTo(20, 1e-9));
      expect(negocio.falta, closeTo(20, 1e-9));
    });
  });

  group('Variación contra el mes anterior', () {
    test('Sube si el último mes mejora la proyección', () {
      final proyeccion = service.calcular(
        porMes: {
          8: [_c(4)],
          9: [_c(8)],
        },
        mesCorte: 9,
      )!;
      // Agosto: 4 h y 4 meses a 4 h = 20 de 40 (50 %). Septiembre llega.
      expect(proyeccion.porcentajeAnterior, closeTo(50, 1e-9));
      expect(proyeccion.porcentaje, 100);
      expect(proyeccion.variacionProyeccion, closeTo(50, 1e-9));
    });

    test('Baja si el último mes empeora la proyección', () {
      final proyeccion = service.calcular(
        porMes: {
          8: [_c(8)],
          9: [_c(0)],
        },
        mesCorte: 9,
      )!;
      expect(proyeccion.variacionProyeccion, lessThan(0));
    });

    test('Sin mes anterior con datos no hay variación', () {
      final proyeccion = service.calcular(
        porMes: {
          9: [_c(8)],
        },
        mesCorte: 9,
      )!;
      expect(proyeccion.porcentajeAnterior, isNull);
      expect(proyeccion.variacionProyeccion, isNull);
    });
  });

  test('Sin colaboradores en el mes de corte no hay proyección', () {
    expect(
      service.calcular(
        porMes: {
          8: [_c(8)],
          9: [],
        },
        mesCorte: 9,
      ),
      isNull,
    );
  });
}
