import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/compliance/domain/member_order.dart';
import 'package:app_finnegans/features/compliance/presentation/member_sort_labels.dart';
import 'package:app_finnegans/features/compliance/presentation/providers/member_order_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The order of a members list as a menu, for the cards (without column
/// headers to tap). Same rule as the headers: a column sorts ascending and
/// choosing it again reverses it.
class MemberOrderMenu extends ConsumerWidget {
  final MemberTable table;
  final List<MemberSort> columns;

  const MemberOrderMenu({
    super.key,
    required this.table,
    required this.columns,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(memberOrderProvider(table));
    final cs = context.colorScheme;
    final direction = order.ascending
        ? Icons.arrow_upward
        : Icons.arrow_downward;

    return PopupMenuButton<MemberSort>(
      key: const Key('member_order_button'),
      tooltip: 'Ordenar integrantes',
      // Above the assistant's button, like the filter sheets.
      useRootNavigator: true,
      initialValue: order.column,
      onSelected: (column) =>
          ref.read(memberOrderProvider(table).notifier).sortBy(column),
      itemBuilder: (context) => [
        for (final column in columns)
          PopupMenuItem(
            value: column,
            child: Row(
              children: [
                Expanded(child: Text(column.label)),
                if (column == order.column) ...[
                  const SizedBox(width: 12),
                  Icon(direction, size: 18, color: cs.primary),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 19, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              order.column?.label ?? 'Ordenar',
              style: context.textTheme.labelLarge?.copyWith(
                color: cs.onSurface,
              ),
            ),
            if (order.column != null) ...[
              const SizedBox(width: 4),
              Icon(direction, size: 16, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}
