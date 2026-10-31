import 'package:app_finnegans/core/widgets/paginated_table.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 292 px high: (292 - 60 paginator - 12 spacing - 20 header) / 20 = 10 rows.
Widget _table(List<int> items) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 292,
      width: 600,
      child: PaginatedTable(
        items: items,
        rowHeight: 20,
        headerHeight: 20,
        resultsLabel: 'filas',
        icon: Icons.list,
        tableBuilder: (visible) => Column(
          children: [for (final item in visible) Text('fila $item')],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('Muestra las filas que entran en el alto y pagina el resto', (
    tester,
  ) async {
    await tester.pumpWidget(_table(List.generate(25, (i) => i)));

    expect(find.text('fila 0'), findsOneWidget);
    expect(find.text('fila 9'), findsOneWidget);
    expect(find.text('fila 10'), findsNothing);
    expect(find.byType(ResultsPagination), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    expect(find.text('fila 0'), findsNothing);
    expect(find.text('fila 10'), findsOneWidget);
    expect(find.text('fila 19'), findsOneWidget);
  });

  testWidgets('Con otra lista vuelve a la primera página', (tester) async {
    await tester.pumpWidget(_table(List.generate(25, (i) => i)));
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();

    await tester.pumpWidget(_table(List.generate(25, (i) => i + 100)));

    expect(find.text('fila 100'), findsOneWidget);
    expect(find.text('fila 110'), findsNothing);
  });

  testWidgets('Con una sola página no muestra el paginador', (tester) async {
    await tester.pumpWidget(_table(List.generate(3, (i) => i)));

    expect(find.text('fila 2'), findsOneWidget);
    expect(find.byType(ResultsPagination), findsNothing);
  });
}
