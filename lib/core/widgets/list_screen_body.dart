import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/widgets/screen_padding.dart';
import 'package:flutter/material.dart';

/// The body of a list screen: a [header] (filters, indicators) and the
/// [results].
///
/// From 840 px the results fill the remaining height, so a `PaginatedTable`
/// paginates by it. Below, the whole body scrolls and the results go after
/// the header with their natural height (see `AdaptiveRecordList`).
class ListScreenBody extends StatelessWidget {
  final List<Widget> header;
  final Widget results;

  const ListScreenBody({
    super.key,
    this.header = const [],
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final padding = screenPaddingOf(context);
    if (context.windowSize != WindowSize.expanded) {
      return SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...header, results],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...header,
          Expanded(child: results),
        ],
      ),
    );
  }
}

/// The results' spinner: centered in the table's height, or with a margin
/// when the screen scrolls.
class ListLoading extends StatelessWidget {
  const ListLoading({super.key});

  @override
  Widget build(BuildContext context) =>
      context.windowSize == WindowSize.expanded
      ? const Center(child: CircularProgressIndicator())
      : const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        );
}

/// An empty or error state in place of the results. From 840 px it scrolls
/// on its own, since it fills a bounded height; below, the screen already
/// scrolls.
class ListEmptyState extends StatelessWidget {
  final Widget child;

  const ListEmptyState({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      context.windowSize == WindowSize.expanded
      ? SingleChildScrollView(child: child)
      : child;
}
