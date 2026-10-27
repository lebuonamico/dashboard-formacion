import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/domain/modelos/comparacion_moodle_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter/material.dart';

/// Dos cards lado a lado: Moodle vs CRM en las categorías comparables
/// (Negocio y Blandas) y el total de cada fuente, con el desglose por
/// categoría de cada número.
class ComparacionMoodleCrmCards extends StatelessWidget {
  final List<CumplimientoEmpleado> cumplimientos;

  const ComparacionMoodleCrmCards({super.key, required this.cumplimientos});

  @override
  Widget build(BuildContext context) {
    final comparacion = ComparacionMoodleCrm.desde(cumplimientos);
    final comparables = _CardComparacion(
      key: const Key('comparacion_comparables'),
      comparacion: comparacion,
    );
    final total = _CardTotalCrm(
      key: const Key('comparacion_total'),
      comparacion: comparacion,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [comparables, const SizedBox(height: 16), total],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: comparables),
              const SizedBox(width: 16),
              Expanded(child: total),
            ],
          ),
        );
      },
    );
  }
}

/// Moodle vs CRM en Negocio y Blandas, con columnas agrupadas por categoría.
class _CardComparacion extends StatelessWidget {
  final ComparacionMoodleCrm comparacion;

  const _CardComparacion({super.key, required this.comparacion});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colorMoodle = cs.primary;
    final colorCrm = context.colores.acentoCian;
    const tipos = ComparacionMoodleCrm.comparables;
    final moodle = comparacion.totalMoodle(tipos);
    final crm = comparacion.totalCrm(tipos);

    return _Panel(
      titulo: 'Moodle vs CRM · Comparables',
      subtitulo:
          'Negocio y Blandas, las categorías que existen en las dos fuentes',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _Total(
                fuente: 'MOODLE (LMS)',
                horas: moodle,
                color: colorMoodle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'vs',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: _Total(
                fuente: 'CRM',
                horas: crm,
                color: colorCrm,
                alinearDerecha: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _textoDiferencia(),
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: 10),
        _GraficoColumnas(
          tipos: tipos,
          comparacion: comparacion,
          colorMoodle: colorMoodle,
          colorCrm: colorCrm,
        ),
      ],
    );
  }

  String _textoDiferencia() {
    if (comparacion.coinciden) return 'Las dos fuentes coinciden.';
    final diferencia = comparacion.diferenciaComparable;
    final porcentaje = switch (comparacion.diferenciaPorcentual) {
      final p? => ' (${p > 0 ? '+' : ''}${p.toStringAsFixed(0)}%)',
      null => '',
    };
    return 'CRM registra ${diferencia.abs().toStringAsFixed(1)} h '
        '${diferencia > 0 ? 'más' : 'menos'} que Moodle$porcentaje';
  }
}

class _Total extends StatelessWidget {
  final String fuente;
  final double horas;
  final Color color;
  final bool alinearDerecha;

  const _Total({
    required this.fuente,
    required this.horas,
    required this.color,
    this.alinearDerecha = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alinearDerecha
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          fuente,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${horas.toStringAsFixed(1)} h',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Contenedor de las cards de la comparación: título, subtítulo y contenido.
class _Panel extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  const _Panel({
    required this.titulo,
    required this.subtitulo,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: context.panel(sombra: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Total de horas CRM y cómo se reparten entre las cuatro categorías.
class _CardTotalCrm extends StatelessWidget {
  final ComparacionMoodleCrm comparacion;

  const _CardTotalCrm({super.key, required this.comparacion});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colorCrm = context.colores.acentoCian;
    final total = comparacion.totalCrm(TipoCurso.values);

    return _Panel(
      titulo: 'Horas CRM · Total',
      subtitulo: 'Todas las horas declaradas en CRM, por categoría',
      children: [
        _Total(fuente: 'CRM', horas: total, color: colorCrm),
        // Misma altura que la línea de diferencia de la otra card, para que
        // los divisores queden alineados.
        const SizedBox(height: 8),
        Text(
          'Repartidas entre las 4 categorías del plan',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: cs.outlineVariant),
        const SizedBox(height: 10),
        _GraficoCrm(crm: comparacion.crm, total: total),
      ],
    );
  }
}

/// Una columna por categoría del CRM, con su color y en una escala común a
/// las cuatro: horas arriba, nombre y parte del total abajo.
class _GraficoCrm extends StatelessWidget {
  final Map<TipoCurso, double> crm;
  final double total;

  const _GraficoCrm({required this.crm, required this.total});

  @override
  Widget build(BuildContext context) {
    final maximo = TipoCurso.values
        .map((tipo) => crm[tipo] ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final tipo in TipoCurso.values)
            Expanded(
              child: _Columna(
                key: Key('comparacion_${tipo.name}'),
                horas: crm[tipo] ?? 0,
                maximo: maximo,
                alto: _GraficoColumnas._altoMaximo,
                color: context.colores.categoria(tipo).texto,
                fuente:
                    '${tipo.labelCorto}\n'
                    '${(total == 0 ? 0 : (crm[tipo] ?? 0) / total * 100).toStringAsFixed(0)}%',
              ),
            ),
        ],
      ),
    );
  }
}

/// Columnas agrupadas: un grupo por categoría, con la columna de Moodle y la
/// de CRM en la misma escala, separados por una línea vertical.
class _GraficoColumnas extends StatelessWidget {
  final List<TipoCurso> tipos;
  final ComparacionMoodleCrm comparacion;
  final Color colorMoodle;
  final Color colorCrm;

  const _GraficoColumnas({
    required this.tipos,
    required this.comparacion,
    required this.colorMoodle,
    required this.colorCrm,
  });

  static const _altoMaximo = 150.0;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final maximo = [
      for (final tipo in tipos) ...[
        comparacion.moodle[tipo] ?? 0,
        comparacion.crm[tipo] ?? 0,
      ],
    ].fold<double>(0, (a, b) => a > b ? a : b);

    Widget grupo(TipoCurso tipo) => Expanded(
      key: Key('comparacion_${tipo.name}'),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Columna(
                horas: comparacion.moodle[tipo] ?? 0,
                maximo: maximo,
                alto: _altoMaximo,
                color: colorMoodle,
                fuente: 'Moodle',
              ),
              const SizedBox(width: 16),
              _Columna(
                horas: comparacion.crm[tipo] ?? 0,
                maximo: maximo,
                alto: _altoMaximo,
                color: colorCrm,
                fuente: 'CRM',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.colores.categoria(tipo).texto,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tipo.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tipos.length; i++) ...[
              if (i > 0) VerticalDivider(width: 24, color: cs.outlineVariant),
              grupo(tipos[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una columna con las horas arriba y la fuente abajo.
class _Columna extends StatelessWidget {
  final double horas;
  final double maximo;
  final double alto;
  final Color color;
  final String fuente;

  const _Columna({
    super.key,
    required this.horas,
    required this.maximo,
    required this.alto,
    required this.color,
    required this.fuente,
  });

  static const _ancho = 64.0;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final altura = maximo == 0 ? 0.0 : alto * (horas / maximo).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Alto fijo para que todas las columnas apoyen en la misma base; las
        // horas van justo encima de cada columna.
        SizedBox(
          height: alto + 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${horas.toStringAsFixed(0)} h',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: _ancho,
                height: altura,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fuente,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
