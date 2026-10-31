import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pantalla mínima que maneja el estado como lo hacen las pantallas reales.
class _Host extends StatefulWidget {
  final double width;

  const _Host({this.width = 1200});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? status;
  int? year;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: widget.width,
              child: FilterBar(
                scope: DataFilterScope.employees,
                rows: const AsyncValue.data([]),
                hasActiveExtraFilters: status != null || year != null,
                extraFilters: [
                  FilterDropdown<String?>(
                    value: status,
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
                    onChanged: (value) => setState(() => status = value),
                  ),
                  FilterDropdown<int?>(
                    value: year,
                    hint: 'Todos los años',
                    icon: Icons.event_outlined,
                    // Deshabilitado hasta que haya un estado elegido.
                    onChanged: status == null
                        ? null
                        : (value) => setState(() => year = value),
                    tooltip: status == null ? 'Elegí un estado primero' : null,
                    items: const [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos los años'),
                      ),
                      DropdownMenuItem<int?>(value: 2026, child: Text('2026')),
                    ],
                  ),
                ],
                onClearExtraFilters: () => setState(() {
                  status = null;
                  year = null;
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

OutlinedButton _clear(WidgetTester tester) => tester.widget<OutlinedButton>(
  find.widgetWithText(OutlinedButton, 'Limpiar'),
);

void main() {
  group('FilterBar', () {
    testWidgets('el desplegable cambia el filtro y "Limpiar" se habilita', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());
      expect(_clear(tester).onPressed, isNull);

      await tester.tap(find.byType(FilterDropdown<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estado A').last);
      await tester.pumpAndSettle();

      final status = tester.state<_HostState>(find.byType(_Host));
      expect(status.status, 'a');
      expect(_clear(tester).onPressed, isNotNull);
    });

    testWidgets('un desplegable con onChanged nulo queda deshabilitado', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());

      await tester.tap(find.byType(FilterDropdown<int?>), warnIfMissed: false);
      await tester.pumpAndSettle();

      // No se abrió el menú: no aparece la opción 2026.
      expect(find.text('2026'), findsNothing);
    });

    testWidgets('en pantallas angostas pasa a columna sin desbordes', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(width: 500));

      expect(tester.takeException(), isNull);
      // Todos los controles siguen a la vista.
      expect(find.byType(FilterDropdown<String?>), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
    });
  });
}
