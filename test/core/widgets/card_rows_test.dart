import 'package:app_finnegans/core/widgets/card_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A card of a given content height, with a `Spacer` like the summary cards.
class _Card extends StatelessWidget {
  final double height;

  const _Card(this.height, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(height: height),
      const Spacer(),
      const Text('pie'),
    ],
  );
}

Future<void> _show(WidgetTester tester, Widget rows) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 400, child: rows)),
    ),
  ),
);

void main() {
  testWidgets('Cada fila mide lo que su tarjeta más alta', (tester) async {
    await _show(
      tester,
      const CardRows(
        columns: 2,
        children: [
          _Card(40, key: Key('a')),
          _Card(100, key: Key('b')),
          _Card(20, key: Key('c')),
        ],
      ),
    );

    final a = tester.getSize(find.byKey(const Key('a')));
    final b = tester.getSize(find.byKey(const Key('b')));
    final c = tester.getSize(find.byKey(const Key('c')));
    expect(a.height, b.height);
    expect(c.height, lessThan(b.height));
    // The incomplete row keeps the column width.
    expect(c.width, a.width);
    expect(a.width, (400 - 16) / 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A una columna cada tarjeta mide su contenido', (tester) async {
    await _show(
      tester,
      const CardRows(
        children: [
          _Card(40, key: Key('a')),
          _Card(100, key: Key('b')),
        ],
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('a'))).height,
      lessThan(tester.getSize(find.byKey(const Key('b'))).height),
    );
    expect(tester.getSize(find.byKey(const Key('a'))).width, 400);
  });
}
