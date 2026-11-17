import 'package:app_finnegans/features/areas/presentation/widgets/area_teams_grid.dart';
import 'package:app_finnegans/features/teams/domain/team_overview.dart';
import 'package:app_finnegans/features/teams/domain/team_status.dart';
import 'package:app_finnegans/features/teams/presentation/widgets/team_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/pump_screen.dart';

TeamOverview _team(String name, TeamStatus status) => TeamOverview(
  id: 'desarrollo-$name',
  name: name,
  area: 'Desarrollo',
  leader: 'Ana',
  memberCount: 3,
  membersOnTarget: 1,
  completedHours: 18,
  targetHours: 24,
  hoursDeviation: -6,
  businessHours: 8,
  softSkillsHours: 10,
  explorationHours: 0,
  teachingHours: 0,
  averageHoursPerMember: 6,
  completionPercentage: 75,
  status: status,
);

Future<void> _show(WidgetTester tester, Size size) => pumpScreen(
  tester,
  size: size,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => Scaffold(
        body: SingleChildScrollView(
          child: AreaTeamsGrid(
            origin: 'areas',
            teams: [
              _team('Core', TeamStatus.atRisk),
              _team('Frontend', TeamStatus.critical),
            ],
          ),
        ),
      ),
    ),
  ],
);

void main() {
  testWidgets('A 390 px las tarjetas miden lo que su contenido', (
    tester,
  ) async {
    await _show(tester, compactSize);

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(TeamCard), findsNWidgets(2));
    expect(find.text('3 integrantes'), findsNWidgets(2));
    // Without the desktop grid's fixed 252 px.
    expect(tester.getSize(find.byType(TeamCard).first).height, lessThan(252));
  });

  testWidgets('En escritorio sigue la grilla de alto fijo', (tester) async {
    await _show(tester, desktopSize);

    expect(find.byType(GridView), findsOne);
    expect(tester.getSize(find.byType(TeamCard).first).height, 252);
  });
}
