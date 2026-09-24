import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/estado_equipo.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/equipos_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = EquiposService();

  group('EquiposService', () {
    test('filtra las cargas por mes o por año', () {
      final cargas = [
        _carga('enero', DateTime(2026, 1, 10)),
        _carga('febrero', DateTime(2026, 2, 10)),
        _carga('otro-anio', DateTime(2025, 1, 10)),
      ];

      final enero = service.filtrarCargasPorPeriodo(
        cargas: cargas,
        anio: 2026,
        mes: 1,
        esAnual: false,
      );
      final anioCompleto = service.filtrarCargasPorPeriodo(
        cargas: cargas,
        anio: 2026,
        mes: 1,
        esAnual: true,
      );

      expect(enero.map((carga) => carga.id), ['enero']);
      expect(anioCompleto.map((carga) => carga.id), ['enero', 'febrero']);
    });

    test(
      'convierte los objetivos mensuales a anuales sin alterar las horas',
      () {
        final cumplimiento = _cumplimiento(
          legajo: '1',
          horasNegocio: 4,
          horasBlandas: 2,
          objetivoNegocio: 4,
          objetivoBlandas: 4,
        );

        final anual = service.convertirObjetivoMensualAAnual([
          cumplimiento,
        ]).single;

        expect(anual.totalHorasCompletadas, 6);
        expect(anual.horasRequeridas[TipoCurso.habilidadesDeNegocio], 48);
        expect(anual.horasRequeridas[TipoCurso.habilidadesBlandas], 48);
      },
    );

    test('agrupa por equipo y calcula los indicadores de la tarjeta', () {
      final equipos = service.calcularEquiposGlobales([
        _cumplimiento(
          legajo: '1',
          horasNegocio: 4,
          horasBlandas: 4,
          objetivoNegocio: 4,
          objetivoBlandas: 4,
        ),
        _cumplimiento(
          legajo: '2',
          horasNegocio: 2,
          horasBlandas: 0,
          objetivoNegocio: 4,
          objetivoBlandas: 4,
        ),
      ]);

      final equipo = equipos.single;
      expect(equipo.id, 'desarrollo-backend');
      expect(equipo.cantidadIntegrantes, 2);
      expect(equipo.integrantesEnObjetivo, 1);
      expect(equipo.horasRealizadas, 10);
      expect(equipo.horasObjetivo, 16);
      expect(equipo.desvioHoras, -6);
      expect(equipo.horasNegocio, 6);
      expect(equipo.horasBlandas, 4);
      expect(equipo.promedioPorColaborador, 5);
      expect(equipo.porcentajeCumplimiento, 62.5);
      expect(equipo.estado, EstadoEquipo.enRiesgo);
    });

    test(
      'sólo marca verde si todo el equipo cumple su objetivo individual',
      () {
        expect(
          service.calcularEstadoEquipo(
            porcentajeCumplimiento: 120,
            cantidadIntegrantes: 2,
            integrantesEnObjetivo: 1,
          ),
          EstadoEquipo.enRiesgo,
        );
        expect(
          service.calcularEstadoEquipo(
            porcentajeCumplimiento: 100,
            cantidadIntegrantes: 2,
            integrantesEnObjetivo: 2,
          ),
          EstadoEquipo.enObjetivo,
        );
      },
    );
  });
}

CargaDeHorasCRM _carga(String id, DateTime fecha) {
  return CargaDeHorasCRM(
    id: id,
    cursoId: 'curso-1',
    empleadoLegajo: '1',
    fecha: fecha,
    horasTotales: 2,
    tipo: TipoCargaDeHoras.tomada,
  );
}

CumplimientoEmpleado _cumplimiento({
  required String legajo,
  required double horasNegocio,
  required double horasBlandas,
  required double objetivoNegocio,
  required double objetivoBlandas,
}) {
  return CumplimientoEmpleado(
    empleado: Empleado(
      legajo: legajo,
      nombre: 'Persona',
      apellido: legajo,
      seniority: Seniority.junior1,
      area: 'Desarrollo',
      mail: 'persona$legajo@finnegans.com',
      equipo: 'Backend',
      gerente: 'Líder Backend',
    ),
    horasCompletadas: {
      TipoCurso.habilidadesDeNegocio: horasNegocio,
      TipoCurso.habilidadesBlandas: horasBlandas,
    },
    horasRequeridas: {
      TipoCurso.habilidadesDeNegocio: objetivoNegocio,
      TipoCurso.habilidadesBlandas: objetivoBlandas,
    },
  );
}
