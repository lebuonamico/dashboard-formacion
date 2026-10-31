import 'package:app_finnegans/features/compliance/domain/member_order.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/member_order_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.listen(memberOrderProvider(MemberTable.team), (_, _) {});
    container.listen(memberOrderProvider(MemberTable.area), (_, _) {});
  });
  tearDown(() => container.dispose());

  MemberOrder order(MemberTable table) =>
      container.read(memberOrderProvider(table));
  MemberOrderNotifier notifier(MemberTable table) =>
      container.read(memberOrderProvider(table).notifier);

  test('Arranca sin columna', () {
    expect(order(MemberTable.team).column, isNull);
    expect(order(MemberTable.team).ascending, isTrue);
  });

  test('La misma columna alterna el sentido', () {
    notifier(MemberTable.team).sortBy(MemberSort.hours);
    expect(order(MemberTable.team).column, MemberSort.hours);
    expect(order(MemberTable.team).ascending, isTrue);

    notifier(MemberTable.team).sortBy(MemberSort.hours);
    expect(order(MemberTable.team).ascending, isFalse);
  });

  test('Otra columna vuelve a ascendente', () {
    notifier(MemberTable.team)
      ..sortBy(MemberSort.hours)
      ..sortBy(MemberSort.hours)
      ..sortBy(MemberSort.employee);

    expect(order(MemberTable.team).column, MemberSort.employee);
    expect(order(MemberTable.team).ascending, isTrue);
  });

  test('Cada tabla tiene su orden y clear lo descarta', () {
    notifier(MemberTable.team).sortBy(MemberSort.hours);

    expect(order(MemberTable.area).column, isNull);

    notifier(MemberTable.team).clear();
    expect(order(MemberTable.team).column, isNull);
  });
}
