import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/widgets/card_rows.dart';
import 'package:app_finnegans/core/widgets/page_window.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

/// A list that is a table from 840 px and cards below.
///
/// From 840 px it returns [table] as is: usually a `PaginatedTable`, which
/// needs a bounded height. Below, it shows [pageSize] cards per page and
/// needs no bounded height, so the screen can scroll as a whole. From 600 px
/// the cards go two per row, each row as tall as its tallest card (see
/// [CardRows]). Like the tables, it goes back to the first page
/// when [items] changes: by content, or by [itemId] when the items are
/// rebuilt as new objects without `==`.
class AdaptiveRecordList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(List<T> items) table;
  final Widget Function(T item) card;
  final String resultsLabel;
  final IconData icon;
  final int pageSize;
  final Object? Function(T item)? itemId;

  const AdaptiveRecordList({
    super.key,
    required this.items,
    required this.table,
    required this.card,
    required this.resultsLabel,
    required this.icon,
    this.pageSize = 10,
    this.itemId,
  });

  @override
  State<AdaptiveRecordList<T>> createState() => _AdaptiveRecordListState<T>();
}

class _AdaptiveRecordListState<T> extends State<AdaptiveRecordList<T>> {
  static const _spacing = 12.0;

  /// The list's top, to bring it back into view when the page changes.
  final _top = GlobalKey();
  int _page = 0;

  @override
  void didUpdateWidget(covariant AdaptiveRecordList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // By content: a screen that rebuilds the same list keeps its page.
    final id = widget.itemId;
    final same = id == null
        ? const ListEquality<Object?>().equals(oldWidget.items, widget.items)
        : const IterableEquality<Object?>().equals(
            oldWidget.items.map(id),
            widget.items.map(id),
          );
    if (!same) _page = 0;
  }

  void _goTo(int page) {
    setState(() => _page = page);
    // The pagination sits below the cards: after a change, the new page
    // starts above the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final top = _top.currentContext;
      if (top == null || Scrollable.maybeOf(top) == null) return;
      Scrollable.ensureVisible(
        top,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = context.windowSize;
    if (windowSize == WindowSize.expanded) return widget.table(widget.items);

    final total = widget.items.length;
    final (page: page, pageCount: pageCount, :start, :end) = pageWindow(
      page: _page,
      pageSize: widget.pageSize,
      total: total,
    );
    final cards = [
      for (final item in widget.items.sublist(start, end)) widget.card(item),
    ];
    return Column(
      key: _top,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardRows(
          columns: windowSize == WindowSize.medium ? 2 : 1,
          spacing: _spacing,
          children: cards,
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: _spacing),
          ResultsPagination(
            currentPage: page,
            pageCount: pageCount,
            from: start + 1,
            until: end,
            totalResults: total,
            resultsLabel: widget.resultsLabel,
            icon: widget.icon,
            onPrevious: page > 0 ? () => _goTo(page - 1) : null,
            onNext: page < pageCount - 1 ? () => _goTo(page + 1) : null,
          ),
        ],
      ],
    );
  }
}
