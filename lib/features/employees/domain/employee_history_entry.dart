import 'package:app_finnegans/features/imports/domain/import_values.dart';
import 'package:app_finnegans/features/employees/domain/employee.dart';
import 'package:app_finnegans/features/employees/domain/seniority.dart';

/// Vigencia existente en public.empleado_historial; no genera historia nueva.
class EmployeeHistoryEntry {
  final String employeeId;
  final Seniority seniority;
  final String area;
  final String team;
  final String manager;
  final bool isActive;
  final DateTime validFrom;
  final DateTime? validTo;

  const EmployeeHistoryEntry({
    required this.employeeId,
    required this.seniority,
    required this.area,
    required this.team,
    required this.manager,
    required this.isActive,
    required this.validFrom,
    this.validTo,
  });

  factory EmployeeHistoryEntry.fromJson(Map<String, dynamic> json) {
    if (json['activo'] is! bool ||
        (json['legajo']?.toString().trim() ?? '').isEmpty) {
      throw const FormatException('Estado inválido en empleado_historial.');
    }
    final from = requiredDate(json['vigente_desde']?.toString() ?? '');
    final until = json['vigente_hasta'] == null
        ? null
        : requiredDate(json['vigente_hasta'].toString());
    if (until != null && until.isBefore(from)) {
      throw const FormatException('Intervalo inválido en empleado_historial.');
    }
    final seniorityText = json['seniority']?.toString() ?? '';
    String normalize(String text) => text
        .trim()
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final normalized = normalize(seniorityText);
    final configured = Seniority.values.any(
      (seniority) =>
          normalize(seniority.name) == normalized ||
          normalize(seniority.label) == normalized,
    );
    final alias = RegExp(
      r'^trainee(?:[123]|i{1,3})?$|^t$'
      r'|^(?:junior|jr|j|senior|senor|sr|s)(?:[123]|i{1,3})?$'
      r'|^(?:semisenior|semisenor|ssr|ss)(?:[123]|i{1,3})$'
      r'|^(?:manager|gerente|m)$',
    ).hasMatch(normalized);
    if (!configured && !alias) {
      throw FormatException(
        'Seniority inválido en empleado_historial: "$seniorityText".',
      );
    }
    return EmployeeHistoryEntry(
      employeeId: json['legajo'].toString(),
      seniority: Seniority.fromString(seniorityText),
      area: json['sector']?.toString() ?? '',
      team: json['equipo_general']?.toString() ?? '',
      manager: json['gerente']?.toString() ?? '',
      isActive: json['activo'] as bool,
      validFrom: from,
      validTo: until,
    );
  }

  Employee rebuild(Employee employee) => employee.copyWith(
    seniority: seniority,
    area: area,
    team: team,
    manager: manager,
    active: isActive,
  );
}
