/// The page of a paginated list being shown and its bounds in the list.
typedef PageWindow = ({int page, int pageCount, int start, int end});

/// Clamps [page] to the existing pages. An empty list has one empty page.
PageWindow pageWindow({
  required int page,
  required int pageSize,
  required int total,
}) {
  final pageCount = total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
  final safePage = page.clamp(0, pageCount - 1);
  final start = safePage * pageSize;
  return (
    page: safePage,
    pageCount: pageCount,
    start: start,
    end: (start + pageSize).clamp(0, total),
  );
}
