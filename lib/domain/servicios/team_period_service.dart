import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/certificacion_moodle.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/curso.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/empleado_historial.dart';
import 'package:app_finnegans/domain/modelos/team_identity.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:app_finnegans/domain/servicios/cumplimiento_service.dart';

class TeamPeriodService {
  const TeamPeriodService();

  bool hasDataInPeriod({
    required List<CargaDeHorasCRM> timeEntries,
    required List<CertificacionMoodle> certifications,
    required int year,
    required int month,
    required bool isAnnual,
  }) {
    bool isInPeriod(DateTime date) =>
        date.year == year && (isAnnual || date.month == month);

    return timeEntries.any((entry) => isInPeriod(entry.fecha)) ||
        certifications.any((certification) {
          final date = certification.fechaFinalizacion;
          return date != null && isInPeriod(date);
        });
  }

  List<CargaDeHorasCRM> filterTimeEntriesByPeriod({
    required List<CargaDeHorasCRM> timeEntries,
    required int year,
    required int month,
    required bool isAnnual,
  }) {
    return timeEntries.where((entry) {
      final matchesYear = entry.fecha.year == year;
      if (isAnnual) return matchesYear;

      return matchesYear && entry.fecha.month == month;
    }).toList();
  }

  List<CertificacionMoodle> filterCertificationsByPeriod({
    required List<CertificacionMoodle> certifications,
    required int year,
    required int month,
    required bool isAnnual,
  }) {
    return certifications.where((certification) {
      final date = certification.fechaFinalizacion;
      if (!certification.finalizoCurso || date == null || date.year != year) {
        return false;
      }
      return isAnnual || date.month == month;
    }).toList();
  }

  List<Empleado> filterEmployeesByPeriod({
    required List<Empleado> employees,
    List<EmpleadoHistorial>? history,
    required int year,
    required int month,
    required bool isAnnual,
    bool Function(Empleado)? includeEmployee,
  }) {
    final nextPeriodStart = DateTime(year, isAnnual ? 13 : month + 1);
    final lastDay = DateTime(year, isAnnual ? 13 : month + 1, 0);
    final historyByEmployeeId = <String, List<EmpleadoHistorial>>{};
    for (final entry in history ?? <EmpleadoHistorial>[]) {
      historyByEmployeeId.putIfAbsent(entry.legajo, () => []).add(entry);
    }

    final eligibleEmployees = <Empleado>[];
    for (final employee in employees) {
      final employmentStart = employee.fechaIngreso;
      if (employmentStart == null) continue;
      final employmentStartDate = DateTime(
        employmentStart.year,
        employmentStart.month,
        employmentStart.day,
      );
      if (employmentStartDate.isAfter(lastDay)) continue;
      if (history == null) {
        if (employee.activo && (includeEmployee?.call(employee) ?? true)) {
          eligibleEmployees.add(employee);
        }
        continue;
      }

      final employeeHistory = historyByEmployeeId[employee.legajo] ?? [];
      final effectiveEntries = employeeHistory.where((entry) {
        final endDate = entry.vigenteHasta;
        return entry.vigenteDesde.isBefore(nextPeriodStart) &&
            (endDate == null || !endDate.isBefore(nextPeriodStart));
      }).toList();
      // Before the first recorded state, use that earliest state rather than the current roster.
      if (effectiveEntries.isEmpty && employeeHistory.isNotEmpty) {
        final earliestEntry = employeeHistory.reduce(
          (previous, current) =>
              current.vigenteDesde.isBefore(previous.vigenteDesde)
              ? current
              : previous,
        );
        if (!earliestEntry.vigenteDesde.isBefore(nextPeriodStart)) {
          effectiveEntries.addAll(
            employeeHistory.where(
              (entry) => entry.vigenteDesde.isAtSameMomentAs(
                earliestEntry.vigenteDesde,
              ),
            ),
          );
        }
      }
      if (effectiveEntries.length != 1) {
        throw StateError(
          'El historial del colaborador ${employee.legajo} no tiene una '
          'vigencia única al cierre de $month/$year.',
        );
      }
      final effectiveEntry = effectiveEntries.single;
      if (effectiveEntry.activo) {
        final historicalEmployee = effectiveEntry.reconstruir(employee);
        if (includeEmployee?.call(historicalEmployee) ?? true) {
          eligibleEmployees.add(historicalEmployee);
        }
      }
    }
    return eligibleEmployees;
  }

  int? lastMonthWithData({
    required List<CargaDeHorasCRM> timeEntries,
    required List<CertificacionMoodle> certifications,
    required int year,
  }) {
    for (var month = 12; month >= 1; month--) {
      if (hasDataInPeriod(
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
        month: month,
        isAnnual: false,
      )) {
        return month;
      }
    }
    return null;
  }

  List<CumplimientoEmpleado> calculateMonthlyCompliance({
    required List<Empleado> employees,
    List<EmpleadoHistorial>? history,
    required List<Curso> courses,
    required List<CargaDeHorasCRM> timeEntries,
    required List<CertificacionMoodle> certifications,
    required int year,
    required int month,
    required CumplimientoService complianceService,
    bool Function(Empleado)? includeEmployee,
  }) {
    return complianceService.calcularCumplimientoGlobal(
      empleados: filterEmployeesByPeriod(
        employees: employees,
        history: history,
        year: year,
        month: month,
        isAnnual: false,
        includeEmployee: includeEmployee,
      ),
      cursos: courses,
      cargasDeHoras: filterTimeEntriesByPeriod(
        timeEntries: timeEntries,
        year: year,
        month: month,
        isAnnual: false,
      ),
      certificacionesMoodle: filterCertificationsByPeriod(
        certifications: certifications,
        year: year,
        month: month,
        isAnnual: false,
      ),
      // The target uses the training plan in effect for the evaluated month.
      anio: year,
      mes: month,
    );
  }

  List<CumplimientoEmpleado> calculateAnnualCompliance({
    required List<Empleado> employees,
    List<EmpleadoHistorial>? history,
    required List<Curso> courses,
    required List<CargaDeHorasCRM> timeEntries,
    required List<CertificacionMoodle> certifications,
    required int year,
    required CumplimientoService complianceService,
    bool Function(Empleado)? includeEmployee,
  }) {
    return accumulateMonths(
      calculateComplianceByMonth(
        employees: employees,
        history: history,
        courses: courses,
        timeEntries: timeEntries,
        certifications: certifications,
        year: year,
        complianceService: complianceService,
        includeEmployee: includeEmployee,
      ).values,
    );
  }

  Map<int, List<CumplimientoEmpleado>> calculateComplianceByMonth({
    required List<Empleado> employees,
    List<EmpleadoHistorial>? history,
    required List<Curso> courses,
    required List<CargaDeHorasCRM> timeEntries,
    required List<CertificacionMoodle> certifications,
    required int year,
    int throughMonth = 12,
    required CumplimientoService complianceService,
    bool Function(Empleado)? includeEmployee,
  }) {
    final timeEntriesByMonth = <int, List<CargaDeHorasCRM>>{};
    for (final entry in timeEntries) {
      if (entry.fecha.year != year) continue;
      timeEntriesByMonth.putIfAbsent(entry.fecha.month, () => []).add(entry);
    }
    final certificationsByMonth = <int, List<CertificacionMoodle>>{};
    for (final certification in certifications) {
      final date = certification.fechaFinalizacion;
      if (date == null || date.year != year) continue;
      certificationsByMonth
          .putIfAbsent(date.month, () => [])
          .add(certification);
    }
    return {
      for (var month = 1; month <= throughMonth; month++)
        // Only months with CRM or LMS records contribute to annual compliance.
        if (timeEntriesByMonth.containsKey(month) ||
            certificationsByMonth.containsKey(month))
          month: calculateMonthlyCompliance(
            employees: employees,
            history: history,
            courses: courses,
            timeEntries: timeEntriesByMonth[month] ?? const [],
            certifications: certificationsByMonth[month] ?? const [],
            year: year,
            month: month,
            complianceService: complianceService,
            includeEmployee: includeEmployee,
          ),
    };
  }

  List<CumplimientoEmpleado> accumulateMonths(
    Iterable<List<CumplimientoEmpleado>> months,
  ) {
    final accumulated = <String, CumplimientoEmpleado>{};

    for (final monthlyCompliance in months) {
      for (final monthly in monthlyCompliance) {
        final employee = monthly.empleado;
        final key =
            '${employee.legajo}::${employee.area}::'
            '${normalizeTeamName(employee.equipo)}';
        final previous = accumulated[key];
        accumulated[key] = CumplimientoEmpleado(
          empleado: monthly.empleado,
          horasValidas: {
            for (final category in TipoCurso.values)
              // Annual hours compensate across months within the same category.
              // Only required months contribute; the accumulated target sets the cap.
              category:
                  (previous?.horasValidas[category] ?? 0) +
                  ((monthly.horasRequeridas[category] ?? 0) > 0
                      ? monthly.horasValidas[category] ?? 0
                      : 0),
          },
          horasDeclaradas: {
            for (final category in TipoCurso.values)
              category:
                  (previous?.horasDeclaradas[category] ?? 0) +
                  (monthly.horasDeclaradas[category] ?? 0),
          },
          horasRequeridas: {
            for (final category in TipoCurso.values)
              category:
                  (previous?.horasRequeridas[category] ?? 0) +
                  (monthly.horasRequeridas[category] ?? 0),
          },
        );
      }
    }

    return accumulated.values.toList();
  }

  bool belongsToTeam(Empleado employee, {String? area, String? team}) {
    if (area != null &&
        normalizeTeamComparison(employee.area) !=
            normalizeTeamComparison(area)) {
      return false;
    }
    return team == null ||
        normalizeTeamComparison(normalizeTeamName(employee.equipo)) ==
            normalizeTeamComparison(normalizeTeamName(team));
  }
}
