import 'package:app_finnegans/core/theme/app_theme.dart';
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
  String? estado;
  int? anio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: widget.ancho,
            child: FilterBar(
              hasActiveFilters: estado != null || anio != null,
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

    testWidgets('un desplegable con onChanged nulo queda deshabilitado', (
      tester,
    ) async {
      await tester.pumpWidget(const _Anfitrion());

      await tester.tap(find.text('Todos los años'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // No se abrió el menú: no aparece la opción 2026.
      expect(find.text('2026'), findsNothing);
    });

    testWidgets('en pantallas angostas pasa a columna sin desbordes', (
      tester,
    ) async {
      await tester.pumpWidget(const _Anfitrion(ancho: 500));

      expect(tester.takeException(), isNull);
      // Todos los controles siguen a la vista.
      expect(find.text('Todos los estados'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
    });
  });
}
