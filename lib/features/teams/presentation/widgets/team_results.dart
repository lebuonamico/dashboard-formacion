import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/core/widgets/result_pagination.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_card.dart';
import 'package:flutter/material.dart';

const _maxCardWidth = 410.0;
const _gridSpacing = 16.0;
const _rowsPerPage = 2;
const _cardHeight = 252.0;

class TeamResults extends StatefulWidget {
  final List<TeamOverview> teams;
  final int teamCount;
  final bool isAnnual;

  const TeamResults({
    super.key,
    required this.teams,
    required this.teamCount,
    this.isAnnual = false,
  });

  @override
  State<TeamResults> createState() => _TeamResultsState();
}

class _TeamResultsState extends State<TeamResults> {
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant TeamResults oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_haveSameTeams(oldWidget.teams, widget.teams)) {
      _currentPage = 0;
    }
  }

  bool _haveSameTeams(
    List<TeamOverview> previousTeams,
    List<TeamOverview> currentTeams,
  ) {
    if (previousTeams.length != currentTeams.length) return false;
    for (var index = 0; index < currentTeams.length; index++) {
      final previous = previousTeams[index];
      final current = currentTeams[index];
      if (previous.id != current.id ||
          previous.completedHours != current.completedHours ||
          previous.targetHours != current.targetHours) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final calculatedColumns =
            (constraints.maxWidth / (_maxCardWidth + _gridSpacing)).ceil();
        final columnCount = calculatedColumns < 1 ? 1 : calculatedColumns;
        final itemsPerPage = columnCount * _rowsPerPage;
        final pageCount = (widget.teams.length / itemsPerPage).ceil();
        final safePage = pageCount == 0
            ? 0
            : _currentPage.clamp(0, pageCount - 1);
        final startIndex = safePage * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(
          0,
          widget.teams.length,
        );
        final visibleTeams = widget.teams.sublist(startIndex, endIndex);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Equipos',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                _CountBadge(count: widget.teams.length),
                const Spacer(),
                Text(
                  widget.teams.length == widget.teamCount
                      ? '${widget.teamCount} equipos en el período'
                      : '${widget.teams.length} de ${widget.teamCount} equipos',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (widget.teams.isEmpty)
              const _EmptySearch()
            else ...[
              if (pageCount > 1) ...[
                ResultsPagination(
                  currentPage: safePage,
                  pageCount: pageCount,
                  from: startIndex + 1,
                  until: endIndex,
                  totalResults: widget.teams.length,
                  resultsLabel: 'equipos',
                  icon: Icons.view_module_outlined,
                  onPrevious: safePage == 0
                      ? null
                      : () => setState(() => _currentPage = safePage - 1),
                  onNext: safePage == pageCount - 1
                      ? null
                      : () => setState(() => _currentPage = safePage + 1),
                ),
                const SizedBox(height: 18),
              ],

              _TeamsGrid(teams: visibleTeams, isAnnual: widget.isAnnual),
            ],
          ],
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.primary,
        ),
      ),
    );
  }
}

class _TeamsGrid extends StatelessWidget {
  final List<TeamOverview> teams;
  final bool isAnnual;

  const _TeamsGrid({required this.teams, required this.isAnnual});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardWidth,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
        mainAxisExtent: _cardHeight,
      ),
      itemCount: teams.length,

      itemBuilder: (context, index) =>
          TeamCard(team: teams[index], isAnnual: isAnnual),
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
            'No encontramos equipos con esos filtros.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Probá con otra búsqueda, área o estado.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
