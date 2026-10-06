import 'package:app_finnegans/domain/importacion/valores_importacion.dart';
import 'package:app_finnegans/domain/modelos/empleado.dart';
import 'package:app_finnegans/domain/modelos/seniority.dart';

/// Vigencia existente en public.empleado_historial; no genera historia nueva.
class EmpleadoHistorial {
  final String legajo;
  final Seniority seniority;
  final String area;
  final String equipo;
  final String gerente;
  final bool activo;
  final DateTime vigenteDesde;
  final DateTime? vigenteHasta;

  const EmpleadoHistorial({
    required this.legajo,
    required this.seniority,
    required this.area,
    required this.equipo,
    required this.gerente,
    required this.activo,
    required this.vigenteDesde,
    this.vigenteHasta,
  });

  factory EmpleadoHistorial.fromJson(Map<String, dynamic> json) {
    if (json['activo'] is! bool ||
        (json['legajo']?.toString().trim() ?? '').isEmpty) {
      throw const FormatException('Estado inválido en empleado_historial.');
    }
    final desde = fechaObligatoria(json['vigente_desde']?.toString() ?? '');
    final hasta = json['vigente_hasta'] == null
        ? null
        : fechaObligatoria(json['vigente_hasta'].toString());
    if (hasta != null && hasta.isBefore(desde)) {
      throw const FormatException('Intervalo inválido en empleado_historial.');
    }
    final textoSeniority = json['seniority']?.toString() ?? '';
    String normalizar(String texto) => texto
        .trim()
        .toLowerCase()
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    final normalizado = normalizar(textoSeniority);
    final configurado = Seniority.values.any(
      (seniority) =>
          normalizar(seniority.name) == normalizado ||
          normalizar(seniority.label) == normalizado,
    );
    final alias = RegExp(
      r'^trainee(?:[123]|i{1,3})?$|^t$'
      r'|^(?:junior|jr|j|senior|senor|sr|s)(?:[123]|i{1,3})?$'
      r'|^(?:semisenior|semisenor|ssr|ss)(?:[123]|i{1,3})$'
      r'|^(?:manager|gerente|m)$',
    ).hasMatch(normalizado);
    if (!configurado && !alias) {
      throw FormatException(
        'Seniority inválido en empleado_historial: "$textoSeniority".',
      );
    }
    return EmpleadoHistorial(
      legajo: json['legajo'].toString(),
      seniority: Seniority.fromString(textoSeniority),
      area: json['sector']?.toString() ?? '',
      equipo: json['equipo_general']?.toString() ?? '',
      gerente: json['gerente']?.toString() ?? '',
      activo: json['activo'] as bool,
      vigenteDesde: desde,
      vigenteHasta: hasta,
    );
  }

  Empleado reconstruir(Empleado empleado) => empleado.copyWith(
    seniority: seniority,
    area: area,
    equipo: equipo,
    gerente: gerente,
    activo: activo,
  );
}
