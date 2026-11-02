import 'package:app_finnegans/features/teams/domain/team_status.dart';

extension TeamStatusLabel on TeamStatus {
  String get label => switch (this) {
    TeamStatus.onTarget => 'En objetivo',
    TeamStatus.atRisk => 'En riesgo',
    TeamStatus.critical => 'Crítico',
  };
}
