import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_bar.dart';
import 'package:app_finnegans/core/data_filters/presentation/filter_dropdown.dart';
import 'package:app_finnegans/core/data_filters/presentation/data_filter_selection_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/core/period/presentation/optional_period_filter.dart';

import '../../support/pump_screen.dart';

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
                activeExtraFilters: [status, year].nonNulls.length,
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
    // Desktop window: below 840 px the bar and the menus change (see the
    // compact tests).
    setUp(() {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = desktopSize;
      view.devicePixelRatio = 1;
    });
    tearDown(
      () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          .reset(),
    );

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

  group('En el teléfono (390 px)', () {
    Future<ProviderContainer> show(WidgetTester tester, {Widget? body}) async {
      final (router: _, :container) = await pumpScreen(
        tester,
        initialLocation: '/',
        size: compactSize,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: body ?? const _CompactBar(),
              ),
            ),
          ),
        ],
      );
      return container;
    }

    Finder sheetButton() => find.byKey(const Key('filter_sheet_button'));
    String sheetLabel(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(of: sheetButton(), matching: find.byType(Text)),
        )
        .data!;

    testWidgets('Los filtros pasan a un botón que abre un sheet; cada '
        'desplegable abre el suyo y "Filtros (n)" cuenta los activos', (
      tester,
    ) async {
      final container = await show(tester);

      expect(sheetButton(), findsOneWidget);
      expect(sheetLabel(tester), 'Filtros');
      expect(find.byType(FilterDropdown<String>), findsNothing);

      await tester.tap(sheetButton());
      await tester.pumpAndSettle();
      expect(find.byType(FilterDropdown<String>), findsNWidgets(3));
      expect(find.text('Listo'), findsOneWidget);

      // Un filtro de la nómina: su propio sheet, sin búsqueda en una lista corta.
      await tester.tap(find.byType(FilterDropdown<String>).first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'QA'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'QA'),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.text('Listo').last);
      await tester.pumpAndSettle();
      expect(
        container
            .read(dataFilterSelectionProvider(DataFilterScope.employees))
            .values,
        {
          'Área': {'QA'},
        },
      );

      // Un filtro extra con selección única: elegir cierra su sheet.
      await tester.tap(find.byType(OptionalYearFilter));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '2026'));
      await tester.pumpAndSettle();
      expect(container.read(_period).year, 2026);

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(sheetLabel(tester), 'Filtros (2)');

      await tester.tap(find.byTooltip('Limpiar'));
      await tester.pumpAndSettle();
      expect(sheetLabel(tester), 'Filtros');
      expect(container.read(_period).year, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Limpiar" del sheet vacía todo sin cerrarlo', (tester) async {
      final container = await show(tester);
      container.read(_period.notifier).setYear(2025);
      await tester.pump();

      await tester.tap(sheetButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Limpiar'));
      await tester.pumpAndSettle();

      expect(container.read(_period).year, isNull);
      expect(find.text('Listo'), findsOneWidget);
    });

    testWidgets('Una lista larga tiene búsqueda, sin abrir el teclado sola', (
      tester,
    ) async {
      String? chosen;
      await show(
        tester,
        body: StatefulBuilder(
          builder: (context, setState) => SizedBox(
            height: 56,
            child: FilterDropdown<String>(
              value: chosen,
              hint: 'Colaborador',
              icon: Icons.person_outline,
              items: [
                for (var i = 1; i <= 20; i++)
                  DropdownMenuItem(value: 'p$i', child: Text('Persona $i')),
              ],
              onChanged: (value) => setState(() => chosen = value),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FilterDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isFalse);

      await tester.enterText(find.byType(TextField), 'Persona 17');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Persona 17'));
      await tester.pumpAndSettle();

      expect(chosen, 'p17');
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Si entra en la fila, un solo filtro no pasa al sheet', (
      tester,
    ) async {
      await show(
        tester,
        body: FilterBar(
          scope: DataFilterScope.courses,
          rows: const AsyncValue.data([]),
          extraFilters: [
            OptionalYearFilter(provider: _period, availableYears: const [2026]),
          ],
        ),
      );

      expect(sheetButton(), findsNothing);
      expect(find.byType(OptionalYearFilter), findsOneWidget);
    });
  });
}

final _period = OptionalPeriodProvider(OptionalPeriodNotifier.new);

const _rows = [
  FilterRow({'Área': 'Desarrollo', 'Equipo': 'Core', 'Seniority': 'Junior'}),
  FilterRow({'Área': 'QA', 'Equipo': 'Testing', 'Seniority': 'Senior'}),
];

/// A bar like the screens': three payroll filters and a year read from a
/// provider.
class _CompactBar extends ConsumerWidget {
  const _CompactBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilterBar(
    scope: DataFilterScope.employees,
    rows: const AsyncValue.data(_rows),
    extraFilters: [
      OptionalYearFilter(provider: _period, availableYears: const [2025, 2026]),
    ],
    activeExtraFilters: ref.watch(_period).year == null ? 0 : 1,
    onClearExtraFilters: ref.read(_period.notifier).clear,
  );
}
