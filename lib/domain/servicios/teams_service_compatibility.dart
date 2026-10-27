part of 'teams_service.dart';

typedef EquiposService = TeamsService;

extension TeamsServiceCompatibility on TeamsService {
  List<CumplimientoEmpleado> calcularCumplimientoMensual({
    required List<Empleado> empleados,
    List<EmpleadoHistorial>? historial,
    required List<Curso> cursos,
    required List<CargaDeHorasCRM> cargas,
    required List<CertificacionMoodle> certificaciones,
    required int anio,
    required int mes,
    required CumplimientoService cumplimientoService,
    bool Function(Empleado)? incluir,
  }) => periods.calculateMonthlyCompliance(
    employees: empleados,
    history: historial,
    courses: cursos,
    timeEntries: cargas,
    certifications: certificaciones,
    year: anio,
    month: mes,
    complianceService: cumplimientoService,
    includeEmployee: incluir,
  );

  List<CumplimientoEmpleado> calcularCumplimientoAnual({
    required List<Empleado> empleados,
    List<EmpleadoHistorial>? historial,
    required List<Curso> cursos,
    required List<CargaDeHorasCRM> cargas,
    required List<CertificacionMoodle> certificaciones,
    required int anio,
    required CumplimientoService cumplimientoService,
    bool Function(Empleado)? incluir,
  }) => periods.calculateAnnualCompliance(
    employees: empleados,
    history: historial,
    courses: cursos,
    timeEntries: cargas,
    certifications: certificaciones,
    year: anio,
    complianceService: cumplimientoService,
    includeEmployee: incluir,
  );
}
