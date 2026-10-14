import 'package:app_finnegans/presentation/widgets/shared/filter_bar.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pantalla mínima que maneja el estado como lo hacen las pantallas reales.
class _Anfitrion extends StatefulWidget {
  final double ancho;

  const _Anfitrion({this.ancho = 1200});

  @override
  State<_Anfitrion> createState() => _AnfitrionState();
}

class _AnfitrionState extends State<_Anfitrion> {
  String busqueda = '';
  String? estado;
  int? anio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: widget.ancho,
            child: FilterBar(
              searchHint: 'Buscar...',
              searchText: busqueda,
              hasActiveFilters:
                  busqueda.isNotEmpty || estado != null || anio != null,
              onSearch: (value) => setState(() => busqueda = value),
              filters: [
                FilterDropdown<String?>(
                  value: estado,
                  hint: 'Todos los estados',
                  icon: Icons.traffic_outlined,
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos los estados'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'a',
                      child: Text('Estado A'),
                    ),
                  ],
                  onChanged: (value) => setState(() => estado = value),
                ),
                FilterDropdown<int?>(
                  value: anio,
                  hint: 'Todos los años',
                  icon: Icons.event_outlined,
                  // Deshabilitado hasta que haya un estado elegido.
                  onChanged: estado == null
                      ? null
                      : (value) => setState(() => anio = value),
                  tooltip: estado == null ? 'Elegí un estado primero' : null,
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos los años'),
                    ),
                    DropdownMenuItem<int?>(value: 2026, child: Text('2026')),
                  ],
                ),
              ],
              onClear: () => setState(() {
                busqueda = '';
                estado = null;
                anio = null;
              }),
            ),
          ),
        ),
      ),
    );
  }
}

OutlinedButton _limpiar(WidgetTester tester) => tester.widget<OutlinedButton>(
  find.widgetWithText(OutlinedButton, 'Limpiar'),
);

void main() {
  group('FilterBar', () {
    testWidgets('escribir en el buscador actualiza la búsqueda', (
      tester,
    ) async {
      await tester.pumpWidget(const _Anfitrion());

      await tester.enterText(find.byType(TextField), 'ventas');
      await tester.pump();

      final estado = tester.state<_AnfitrionState>(find.byType(_Anfitrion));
      expect(estado.busqueda, 'ventas');
    });

    testWidgets('el desplegable cambia el filtro y "Limpiar" se habilita', (
      tester,
    ) async {
      await tester.pumpWidget(const _Anfitrion());
      expect(_limpiar(tester).onPressed, isNull);

      await tester.tap(find.text('Todos los estados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estado A').last);
      await tester.pumpAndSettle();

      final estado = tester.state<_AnfitrionState>(find.byType(_Anfitrion));
      expect(estado.estado, 'a');
      expect(_limpiar(tester).onPressed, isNotNull);
    });

    testWidgets('"Limpiar" vacía el buscador y vuelve los desplegables a todos', (
      tester,
    ) async {
      await tester.pumpWidget(const _Anfitrion());

      await tester.enterText(find.byType(TextField), 'ventas');
      await tester.tap(find.text('Todos los estados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estado A').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Limpiar'));
      await tester.pumpAndSettle();

      final estado = tester.state<_AnfitrionState>(find.byType(_Anfitrion));
      expect(estado.busqueda, isEmpty);
      expect(estado.estado, isNull);
      // El campo de texto y el desplegable reflejan el vaciado.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(find.text('Estado A'), findsNothing);
      expect(find.text('Todos los estados'), findsOneWidget);
      expect(_limpiar(tester).onPressed, isNull);
    });

    testWidgets('un desplegable con onChanged nulo queda deshabilitado', (
      tester,
    ) async {
      await tester.pumpWidget(const _Anfitrion());

      await tester.tap(find.text('Todos los años'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // No se abrió el menú: no aparece la opción 2026.
      expect(find.text('2026'), findsNothing);
    });

    testWidgets('el texto inicial persiste al volver a la pantalla', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FilterBar(
              searchHint: 'Buscar...',
              searchText: 'guardado',
              hasActiveFilters: true,
              onSearch: _ignorar,
              onClear: _vacio,
            ),
          ),
        ),
      );

      expect(find.text('guardado'), findsOneWidget);
    });

    testWidgets('en pantallas angostas pasa a columna sin desbordes', (
      tester,
    ) async {
      await tester.pumpWidget(const _Anfitrion(ancho: 500));

      expect(tester.takeException(), isNull);
      // Todos los controles siguen a la vista.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Todos los estados'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
    });
  });
}

void _ignorar(String _) {}
void _vacio() {}
