import 'package:app_finnegans/domain/modelos/equipo_global.dart';
import 'package:app_finnegans/domain/modelos/estado_equipo.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipo_card.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adapta la página al ancho disponible y permite avanzar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final equipos = List.generate(9, _equipo);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquiposResults(
              equipos: equipos,
              totalEquipos: equipos.length,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(EquipoCard), findsNWidgets(8));
    expect(find.text('Página 1 de 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pump();

    expect(find.byType(EquipoCard), findsOneWidget);
    expect(find.text('Página 2 de 2'), findsOneWidget);
  });
}

EquipoGlobalViewModel _equipo(int index) {
  return EquipoGlobalViewModel(
    id: 'equipo-$index',
    nombre: 'Equipo $index',
    area: 'Área',
    lider: 'Líder',
    cantidadIntegrantes: 1,
    integrantesEnObjetivo: 0,
    horasRealizadas: index.toDouble(),
    horasObjetivo: 8,
    desvioHoras: index - 8,
    horasNegocio: index.toDouble(),
    horasBlandas: 0,
    horasLibres: 0,
    horasDictado: 0,
    promedioPorColaborador: index.toDouble(),
    porcentajeCumplimiento: index / 8 * 100,
    estado: EstadoEquipo.critico,
  );
}
