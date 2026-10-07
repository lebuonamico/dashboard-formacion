import 'package:flutter/material.dart';
import 'package:app_finnegans/domain/modelos/usuario_autorizado.dart';

({Color texto, Color fondo}) coloresEstadoUsuario(EstadoUsuario estado) =>
    switch (estado) {
      EstadoUsuario.activo => (
        texto: const Color(0xFF16A34A),
        fondo: const Color(0xFFDCFCE7),
      ),
      EstadoUsuario.bloqueado => (
        texto: const Color(0xFFD97706),
        fondo: const Color(0xFFFEF3C7),
      ),
      EstadoUsuario.eliminado => (
        texto: const Color(0xFFDC2626),
        fondo: const Color(0xFFFEE2E2),
      ),
    };

class AdminChip extends StatelessWidget {
  final String label;
  final Color texto;
  final Color fondo;
  final IconData? icono;

  const AdminChip({
    super.key,
    required this.label,
    required this.texto,
    required this.fondo,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: texto),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: texto,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration adminInputDecoration(
  String hint,
  IconData icono, {
  String? label,
  String? error,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
  );

  return InputDecoration(
    labelText: label,
    errorText: error,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
    prefixIcon: Icon(icono, size: 19, color: const Color(0xFF64748B)),
    prefixIconConstraints: const BoxConstraints(minWidth: 42),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF0D53C3), width: 1.5),
    ),
  );
}

String formatearSello(DateTime? fecha) {
  if (fecha == null) return '—';
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year} $hora:$minuto';
}
