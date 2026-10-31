import 'package:app_finnegans/features/compliance/domain/member_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MemberTable { team, area }

final memberOrderServiceProvider = Provider<MemberOrderService>(
  (ref) => const MemberOrderService(),
);

/// Order of each members table. It is discarded when the table leaves the
/// screen.
final memberOrderProvider = NotifierProvider.autoDispose
    .family<MemberOrderNotifier, MemberOrder, MemberTable>(
      MemberOrderNotifier.new,
    );

class MemberOrderNotifier extends Notifier<MemberOrder> {
  MemberOrderNotifier(this.table);

  final MemberTable table;

  @override
  MemberOrder build() => const MemberOrder();

  /// The first tap sorts ascending; tapping the same column again reverses it.
  void sortBy(MemberSort column) => state = MemberOrder(
    column: column,
    ascending: state.column == column ? !state.ascending : true,
  );

  void clear() => state = const MemberOrder();
}
