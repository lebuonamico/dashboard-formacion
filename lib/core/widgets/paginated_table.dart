import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:flutter/material.dart';

/// A full-width table that shows as many rows as fit in the available height
/// and paginates the rest. Goes back to the first page when [items] changes.
class PaginatedTable<T> extends StatefulWidget {
  final List<T> items;
  final double rowHeight;
  final double headerHeight;

  /// Below this width the table scrolls horizontally instead of squeezing its
  /// flex columns. `null` lets the table grow past the available width.
  final double? minimumWidth;
  final String resultsLabel;
  final IconData icon;
  final Widget Function(List<T> visible) tableBuilder;

  const PaginatedTable({
    super.key,
    required this.items,
    required this.rowHeight,
    required this.headerHeight,
    this.minimumWidth,
    required this.resultsLabel,
    required this.icon,
    required this.tableBuilder,
  });

  @override
  State<PaginatedTable<T>> createState() => _PaginatedTableState<T>();
}

class _PaginatedTableState<T> extends State<PaginatedTable<T>> {
  static const _paginatorHeight = 60.0;
  static const _spacing = 12.0;
  static const _minimumPerPage = 5;

  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant PaginatedTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _currentPage = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = widget.items.length;
        final heightForTable =
            constraints.maxHeight - _paginatorHeight - _spacing;
        final perPage =
            ((heightForTable - widget.headerHeight) / widget.rowHeight)
                .floor()
                .clamp(
                  _minimumPerPage,
                  total < _minimumPerPage ? _minimumPerPage : total,
                );

        final totalPages = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
        final safePage = _currentPage.clamp(0, totalPages - 1);
        final start = safePage * perPage;
        final calculatedEnd = start + perPage;
        final end = calculatedEnd > total ? total : calculatedEnd;
        final table = SingleChildScrollView(
          child: widget.tableBuilder(widget.items.sublist(start, end)),
        );
        final minimumWidth = widget.minimumWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Flex columns need a bounded width to share, otherwise they
                // collapse inside the scroll view: a fixed width, not a minimum.
                child: minimumWidth == null
                    ? ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: table,
                      )
                    : SizedBox(
                        width: constraints.maxWidth < minimumWidth
                            ? minimumWidth
                            : constraints.maxWidth,
                        child: table,
                      ),
              ),
            ),
            if (totalPages > 1) ...[
              const SizedBox(height: _spacing),
              ResultsPagination(
                currentPage: safePage,
                pageCount: totalPages,
                from: start + 1,
                until: end,
                totalResults: total,
                resultsLabel: widget.resultsLabel,
                icon: widget.icon,
                onPrevious: safePage > 0
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
                onNext: safePage < totalPages - 1
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }
}
