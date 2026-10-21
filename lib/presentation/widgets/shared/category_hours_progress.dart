import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter/material.dart';

class ProgresoHorasPorCategoria extends StatelessWidget {
  final CumplimientoEmpleado? cumplimiento;
  final bool mostrarSoloHorasAplicables;

  const ProgresoHorasPorCategoria({
    super.key,
    required this.cumplimiento,
    this.mostrarSoloHorasAplicables = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cumplimiento == null) {
      return SizedBox(
        width: 256,
        child: Text(
          'Sin datos de cumplimiento',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      width: 256,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final tipo in TipoCurso.values) _buildFicha(context, tipo),
        ],
      ),
    );
  }

  Widget _buildFicha(BuildContext context, TipoCurso tipo) {
    final colores = context.colores;
    final horasRegistradas = cumplimiento!.horasCompletadas[tipo] ?? 0.0;
    final horasRealizadas = mostrarSoloHorasAplicables
        ? cumplimiento!.horasAplicablesAlObjetivo(tipo)
        : horasRegistradas;
    final horasRequeridas = cumplimiento!.horasRequeridas[tipo] ?? 0.0;
    final requerida = horasRequeridas > 0;
    final cumple = requerida && horasRealizadas >= horasRequeridas;
    final ParColores(texto: color, :fondo) = !requerida
        ? colores.neutro
        : cumple
        ? colores.exito
        : colores.advertencia;

    return Tooltip(
      message: requerida
          ? '${tipo.label}: ${_formatearHoras(horasRealizadas)} de ${_formatearHoras(horasRequeridas)} horas'
          : horasRegistradas > 0
          ? '${tipo.label}: no requerida; ${_formatearHoras(horasRegistradas)} h registradas no suman al cumplimiento'
          : '${tipo.label}: no requerida; no suma al cumplimiento',
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
                style: TextStyle(fontSize: 10, color: colores.textoIntermedio),
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
