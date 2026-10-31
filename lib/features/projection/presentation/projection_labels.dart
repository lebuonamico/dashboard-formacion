import 'package:app_finnegans/features/projection/domain/projection.dart';

extension ProjectionStatusLabel on ProjectionStatus {
  String get label => switch (this) {
    ProjectionStatus.onTrack => 'En camino',
    ProjectionStatus.reachable => 'Alcanzable',
    ProjectionStatus.atRisk => 'En riesgo',
  };
}
