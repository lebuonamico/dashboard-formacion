import 'package:app_finnegans/core/widgets/adaptive_record_list.dart';
import 'package:app_finnegans/core/widgets/record_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/pump_screen.dart';

List<String> _items(int count, {String prefix = 'Ítem'}) => [
  for (var i = 1; i <= count; i++) '$prefix $i',
];

final _itemsProvider = NotifierProvider<_ItemsNotifier, List<String>>(
  _ItemsNotifier.new,
);

class _ItemsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => _items(23);

  void replace(List<String> items) => state = items;
}

/// A screen like the real ones: a header and the list, all in one scroll.
class _Screen extends ConsumerWidget {
  const _Screen();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 300, child: Text('Encabezado')),
          AdaptiveRecordList(
            items: ref.watch(_itemsProvider),
            resultsLabel: 'registros',
            icon: Icons.list,
            table: (items) => Text('Tabla con ${items.length}'),
            card: (item) => RecordCard(title: item, onTap: () {}),
          ),
        ],
      ),
    ),
  );
}

/// A record without `==`, like the ones read again after every change.
class _Entry {
  final String id;

  _Entry(this.id);
}

final _entriesProvider = NotifierProvider<_EntriesNotifier, List<_Entry>>(
  _EntriesNotifier.new,
);

class _EntriesNotifier extends Notifier<List<_Entry>> {
  @override
  List<_Entry> build() => _items(23).map(_Entry.new).toList();

  void replace(List<String> ids) => state = ids.map(_Entry.new).toList();
}

class _EntriesScreen extends ConsumerWidget {
  const _EntriesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SingleChildScrollView(
      child: AdaptiveRecordList<_Entry>(
        items: ref.watch(_entriesProvider),
        itemId: (entry) => entry.id,
        resultsLabel: 'registros',
        icon: Icons.list,
        table: (items) => Text('Tabla con ${items.length}'),
        card: (entry) => RecordCard(title: entry.id),
      ),
    ),
  );
}

Future<ProviderContainer> _show(
  WidgetTester tester,
  Size size, {
  Widget screen = const _Screen(),
}) async {
  final (router: _, :container) = await pumpScreen(
    tester,
    initialLocation: '/',
    size: size,
    routes: [GoRoute(path: '/', builder: (context, state) => screen)],
  );
  return container;
}

void main() {
  testWidgets('Desde 840 px muestra la tabla con todos los ítems', (
    tester,
  ) async {
    await _show(tester, desktopSize);

    expect(find.text('Tabla con 23'), findsOneWidget);
    expect(find.byType(RecordCard), findsNothing);
  });

  testWidgets('En el teléfono: 10 tarjetas por página y paginación', (
    tester,
  ) async {
    await _show(tester, compactSize);

    expect(find.text('Tabla con 23'), findsNothing);
    expect(find.byType(RecordCard), findsNWidgets(10));
    expect(find.text('Ítem 1'), findsOneWidget);
    expect(find.text('Mostrando 1-10 de 23 registros'), findsOneWidget);
    expect(find.text('Página 1 de 3'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Página 2 de 3'), findsOneWidget);
    expect(find.text('Ítem 11'), findsOneWidget);
    expect(find.text('Ítem 1'), findsNothing);
    // The new page starts in view, not above the screen.
    expect(tester.getTopLeft(find.text('Ítem 11')).dy, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Si cambian los ítems vuelve a la primera página', (
    tester,
  ) async {
    final container = await _show(tester, compactSize);
    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 3'), findsOneWidget);

    container.read(_itemsProvider.notifier).replace(_items(15, prefix: 'Otro'));
    await tester.pumpAndSettle();

    expect(find.text('Página 1 de 2'), findsOneWidget);
    expect(find.text('Otro 1'), findsOneWidget);
  });

  testWidgets('Con una sola página no hay paginación', (tester) async {
    final container = await _show(tester, compactSize);
    container.read(_itemsProvider.notifier).replace(_items(4));
    await tester.pumpAndSettle();

    expect(find.byType(RecordCard), findsNWidgets(4));
    expect(find.byTooltip('Página siguiente'), findsNothing);
  });

  testWidgets('En una tablet van dos tarjetas por fila', (tester) async {
    await _show(tester, const Size(768, 1024));

    expect(find.byType(RecordCard), findsNWidgets(10));
    final first = tester.getTopLeft(find.text('Ítem 1'));
    final second = tester.getTopLeft(find.text('Ítem 2'));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
  });

  testWidgets('Con itemId, los mismos ítems releídos conservan la página', (
    tester,
  ) async {
    final container = await _show(
      tester,
      compactSize,
      screen: const _EntriesScreen(),
    );
    await tester.ensureVisible(find.byTooltip('Página siguiente'));
    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 3'), findsOneWidget);

    // New objects, same ids: the page stays.
    container.read(_entriesProvider.notifier).replace(_items(23));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 3'), findsOneWidget);

    container
        .read(_entriesProvider.notifier)
        .replace(_items(23, prefix: 'Otro'));
    await tester.pumpAndSettle();
    expect(find.text('Página 1 de 3'), findsOneWidget);
  });
}
