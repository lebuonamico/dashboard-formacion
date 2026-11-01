import 'package:collection/collection.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/areas/presentation/providers/areas_providers.dart';
import 'package:app_finnegans/features/areas/presentation/widgets/area_card.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/core/widgets/summary_card/count_badge.dart';
import 'package:flutter/material.dart';

const _maxCardWidth = 410.0;
const _gridSpacing = 16.0;
const _rowsPerPage = 2;

class AreasResults extends StatefulWidget {
  final List<AreaSummary> areas;
  final int totalAreas;
  final bool isAnnual;

  const AreasResults({
    super.key,
    required this.areas,
    required this.totalAreas,
    this.isAnnual = false,
  });

  @override
  State<AreasResults> createState() => _AreasResultsState();
}

class _AreasResultsState extends State<AreasResults> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant AreasResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameAreas(oldWidget.areas, widget.areas)) {
      _currentPage = 0;
    }
  }

  bool _sameAreas(List<AreaSummary> previous, List<AreaSummary> current) =>
      const ListEquality<(String, double, double)>().equals(
        previous.map(_resultKey).toList(),
        current.map(_resultKey).toList(),
      );

  (String, double, double) _resultKey(AreaSummary area) =>
      (area.name, area.completedHours, area.targetHours);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final calculatedColumns =
            (constraints.maxWidth / (_maxCardWidth + _gridSpacing)).ceil();
        final columns = calculatedColumns < 1 ? 1 : calculatedColumns;
        final itemsPerPage = columns * _rowsPerPage;
        final pageCount = (widget.areas.length / itemsPerPage).ceil();
        final safePage = pageCount == 0
            ? 0
            : _currentPage.clamp(0, pageCount - 1);
        final from = safePage * itemsPerPage;
        final until = (from + itemsPerPage).clamp(0, widget.areas.length);
        final visibleAreas = widget.areas.sublist(from, until);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Áreas',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                CountBadge(count: widget.areas.length),
                const Spacer(),
                Text(
                  widget.areas.length == widget.totalAreas
                      ? '${widget.totalAreas} áreas en el período'
                      : '${widget.areas.length} de ${widget.totalAreas} áreas',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (widget.areas.isEmpty)
              const _EmptySearch()
            else ...[
              if (pageCount > 1) ...[
                ResultsPagination(
                  currentPage: safePage,
                  pageCount: pageCount,
                  from: from + 1,
                  until: until,
                  totalResults: widget.areas.length,
                  resultsLabel: 'áreas',
                  icon: Icons.apartment_outlined,
                  onPrevious: safePage == 0
                      ? null
                      : () => setState(() => _currentPage = safePage - 1),
                  onNext: safePage == pageCount - 1
                      ? null
                      : () => setState(() => _currentPage = safePage + 1),
                ),
                const SizedBox(height: 18),
              ],
              _AreasGrid(areas: visibleAreas, isAnnual: widget.isAnnual),
            ],
          ],
        );
      },
    );
  }
}

class _AreasGrid extends StatelessWidget {
  final List<AreaSummary> areas;
  final bool isAnnual;

  const _AreasGrid({required this.areas, required this.isAnnual});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        mainAxisExtent: 252,
      ),
      itemCount: areas.length,
      itemBuilder: (context, index) =>
          AreaCard(area: areas[index], isAnnual: isAnnual),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: context.panel(),
      child: Column(
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 30,
            color: context.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            'No hay áreas que coincidan con la búsqueda.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Probá con otra búsqueda o estado.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
