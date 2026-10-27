part of 'team_overview.dart';

class EquipoGlobalViewModel extends TeamOverview {
  const EquipoGlobalViewModel({
    required super.id,
    required String nombre,
    required super.area,
    required String lider,
    required int cantidadIntegrantes,
    required int integrantesEnObjetivo,
    required double horasRealizadas,
    required double horasObjetivo,
    required double desvioHoras,
    required double horasNegocio,
    required double horasBlandas,
    required double horasLibres,
    required double horasDictado,
    required double promedioPorColaborador,
    required double porcentajeCumplimiento,
    required TeamStatus estado,
  }) : super(
         name: nombre,
         leader: lider,
         memberCount: cantidadIntegrantes,
         membersOnTarget: integrantesEnObjetivo,
         completedHours: horasRealizadas,
         targetHours: horasObjetivo,
         hoursDeviation: desvioHoras,
         businessHours: horasNegocio,
         softSkillsHours: horasBlandas,
         explorationHours: horasLibres,
         teachingHours: horasDictado,
         averageHoursPerMember: promedioPorColaborador,
         completionPercentage: porcentajeCumplimiento,
         status: estado,
       );
}

class DetalleEquipoGeneral extends TeamDetail {
  const DetalleEquipoGeneral({
    required TeamOverview resumen,
    required List<CumplimientoEmpleado> miembros,
  }) : super(overview: resumen, members: miembros);
}

typedef ResumenEquiposPeriodo = TeamsPeriodSummary;

extension TeamOverviewCompatibility on TeamOverview {
  String get nombre => name;
  String get lider => leader;
  int get cantidadIntegrantes => memberCount;
  int get integrantesEnObjetivo => membersOnTarget;
  double get horasRealizadas => completedHours;
  double get horasObjetivo => targetHours;
  double get desvioHoras => hoursDeviation;
  double get horasNegocio => businessHours;
  double get horasBlandas => softSkillsHours;
  double get horasLibres => explorationHours;
  double get horasDictado => teachingHours;
  double get promedioPorColaborador => averageHoursPerMember;
  double get porcentajeCumplimiento => completionPercentage;
  TeamStatus get estado => status;
}

extension TeamsPeriodSummaryCompatibility on TeamsPeriodSummary {
  bool get tieneDatos => hasData;
  List<TeamOverview> get equipos => teams;
  int get colaboradores => employeeCount;
  double get horasRealizadas => completedHours;
  double get horasObjetivo => targetHours;
  double get horasNegocio => businessHours;
  double get horasBlandas => softSkillsHours;
  double get horasLibres => explorationHours;
  double get horasDictado => teachingHours;
  int get enObjetivo => onTarget;
  int get enRiesgo => atRisk;
  int get criticos => critical;
  int get totalEquipos => teamCount;
  double get desvioHoras => hoursDeviation;
  double get cumplimientoGlobal => overallCompletion;
}

extension TeamDetailCompatibility on TeamDetail {
  TeamOverview get resumen => overview;
  List<CumplimientoEmpleado> get miembros => members;
}
