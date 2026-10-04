import 'package:app_finnegans/domain/modelos/curso.dart';

String normalizarNombreCurso(String value) => value.trim().toLowerCase();

Curso resolverCurso(String nombre, List<Curso> cursos) {
  final matches = cursos
      .where(
        (c) => normalizarNombreCurso(c.nombre) == normalizarNombreCurso(nombre),
      )
      .toList();
  if (nombre.trim().isEmpty || matches.length != 1) {
    throw FormatException('Curso inexistente o ambiguo: "$nombre".');
  }
  return matches.single;
}

DateTime? fechaImportacion(String value) {
  final texto = value.trim();
  if (texto.isEmpty) return null;
  final partes = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$',
  ).firstMatch(texto);
  if (partes != null) {
    final dia = int.parse(partes[1]!);
    final mes = int.parse(partes[2]!);
    final anio = int.parse(partes[3]!);
    final fecha = DateTime(anio, mes, dia);
    return fecha.year == anio && fecha.month == mes && fecha.day == dia
        ? fecha
        : null;
  }
  final isoParts = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:$|[T ])',
  ).firstMatch(texto);
  if (isoParts != null) {
    final anio = int.parse(isoParts[1]!);
    final mes = int.parse(isoParts[2]!);
    final dia = int.parse(isoParts[3]!);
    final calendario = DateTime(anio, mes, dia);
    if (calendario.year != anio ||
        calendario.month != mes ||
        calendario.day != dia) {
      return null;
    }
    final hora = RegExp(r'[T ](\d{2}):(\d{2})(?::(\d{2}))?').firstMatch(texto);
    if (hora != null &&
        (int.parse(hora[1]!) > 23 ||
            int.parse(hora[2]!) > 59 ||
            int.parse(hora[3] ?? '0') > 59)) {
      return null;
    }
    final fecha = DateTime.tryParse(texto);
    return fecha;
  }
  final serial = double.tryParse(texto.replaceAll(',', '.'));
  if (serial == null || !serial.isFinite || serial < 1 || serial > 2958465) {
    return null;
  }
  return DateTime(
    1899,
    12,
    30,
  ).add(Duration(milliseconds: (serial * Duration.millisecondsPerDay).round()));
}

DateTime fechaObligatoria(String value) {
  return fechaImportacion(value) ??
      (throw FormatException('Fecha inválida: "$value".'));
}
