import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter/material.dart';

class ProgresoHorasPorCategoria extends StatelessWidget {
  final CumplimientoEmpleado? cumplimiento;

  const ProgresoHorasPorCategoria({super.key, required this.cumplimiento});

  @override
  Widget build(BuildContext context) {
    if (cumplimiento == null) {
      return const SizedBox(
        width: 256,
        child: Text(
          'Sin datos de cumplimiento',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return SizedBox(
      width: 256,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: TipoCurso.values.map(_buildFicha).toList(),
      ),
    );
  }

  Widget _buildFicha(TipoCurso tipo) {
    final horasRealizadas = cumplimiento!.horasCompletadas[tipo] ?? 0.0;
    final horasRequeridas = cumplimiento!.horasRequeridas[tipo] ?? 0.0;
    final requerida = horasRequeridas > 0;
    final cumple = requerida && horasRealizadas >= horasRequeridas;
    final color = !requerida
        ? const Color(0xFF64748B)
        : cumple
        ? const Color(0xFF15803D)
        : const Color(0xFFB45309);
    final fondo = !requerida
        ? const Color(0xFFF1F5F9)
        : cumple
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFFFBEB);

    return Tooltip(
      message: requerida
          ? '${tipo.label}: ${_formatearHoras(horasRealizadas)} de ${_formatearHoras(horasRequeridas)} horas'
          : '${tipo.label}: no requerida',
      child: Container(
        width: 125,
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _nombreCorto(tipo),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_formatearHoras(horasRealizadas)}/${_formatearHoras(horasRequeridas)} h',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _nombreCorto(TipoCurso tipo) {
    switch (tipo) {
      case TipoCurso.habilidadesDeNegocio:
        return 'Negocio';
      case TipoCurso.habilidadesBlandas:
        return 'Blandas';
      case TipoCurso.libresExploracion:
        return 'Exploración';
      case TipoCurso.dictadoCapacitaciones:
        return 'Dictado';
    }
  }

  String _formatearHoras(double horas) => horas == horas.roundToDouble()
      ? horas.toStringAsFixed(0)
      : horas.toStringAsFixed(1);
}
