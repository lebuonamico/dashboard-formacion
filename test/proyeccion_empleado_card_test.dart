import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/proyeccion_service.dart';
import 'package:app_finnegans/presentation/widgets/shared/proyeccion_empleado_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mostrar(WidgetTester tester, ProyeccionEmpleado proyeccion) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProyeccionEmpleadoCard(proyeccion: proyeccion, anio: 2026),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Si no llega, dice qué habilidades reforzar y cuánto', (
    tester,
  ) async {
    // Septiembre: faltan 3 meses.
    await _mostrar(
      tester,
      const ProyeccionEmpleado(
        legajo: '1',
        mesCorte: 9,
        categorias: [
          ProyeccionCategoria(
            tipo: TipoCurso.habilidadesBlandas,
            acumulado: 10,
            meta: 16,
            proyectado: 14,
          ),
          ProyeccionCategoria(
            tipo: TipoCurso.habilidadesDeNegocio,
            acumulado: 8,
            meta: 16,
            proyectado: 13,
          ),
          ProyeccionCategoria(
            tipo: TipoCurso.libresExploracion,
            acumulado: 6,
            meta: 8,
            proyectado: 9,
          ),
        ],
      ),
    );

    expect(find.text('Para llegar a diciembre tiene que reforzar:'), findsOne);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('proyeccion_falta_habilidadesDeNegocio')))
          .data,
      'Habilidades de negocio · faltan 3.0 h (+1.0 h/mes)',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('proyeccion_falta_habilidadesBlandas')))
          .data,
      'Habilidades blandas · faltan 2.0 h (+0.7 h/mes)',
    );
    // Libres llega: no se pide reforzarla.
    expect(
      find.byKey(const Key('proyeccion_falta_libresExploracion')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Si llega, lo dice sin pedir refuerzos', (tester) async {
    await _mostrar(
      tester,
      const ProyeccionEmpleado(
        legajo: '1',
        mesCorte: 9,
        categorias: [
          ProyeccionCategoria(
            tipo: TipoCurso.habilidadesDeNegocio,
            acumulado: 12,
            meta: 16,
            proyectado: 17,
          ),
        ],
      ),
    );

    expect(
      find.text('Con su tendencia cumple todas las habilidades de su plan.'),
      findsOne,
    );
    expect(find.textContaining('reforzar'), findsNothing);
  });
}
