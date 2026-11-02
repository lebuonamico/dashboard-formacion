import 'package:app_finnegans/features/org_structure/domain/org_structure.dart';

/// Areas, teams and their leaders. Only the import creates areas and teams:
/// the app never renames or deletes them. Errors to show are thrown as
/// [FormatException].
abstract class OrgStructureRepository {
  Future<OrgStructure> getStructure();

  /// Creates the new areas and teams of a payroll. Runs before the payroll
  /// sync, so a failure here leaves no half-written employees.
  Future<void> registerMissing(PayrollGaps missing);

  /// Leaves exactly these emails as the area's active leaders. Assignments
  /// are not deleted: the ones that leave end at [now] and the ones that come
  /// back are reactivated.
  Future<void> assignAreaLeaders(
    String areaId,
    Set<String> emails, {
    required DateTime now,
  });

  Future<void> assignTeamLeaders(
    String teamId,
    Set<String> emails, {
    required DateTime now,
  });
}
