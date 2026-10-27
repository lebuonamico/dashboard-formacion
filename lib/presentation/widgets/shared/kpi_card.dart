import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:app_finnegans/presentation/providers/proyeccion_providers.dart';
import 'package:app_finnegans/presentation/utils/period_formatter.dart';
import 'package:app_finnegans/presentation/utils/porcentaje_formatter.dart';
import 'package:app_finnegans/presentation/widgets/shared/estado_colores.dart';
import 'package:flutter/material.dart';

/// Fila de cards de indicadores, la misma en Inicio, Áreas, Equipos y sus
/// detalles: 5 columnas en pantallas anchas, 3 + 2, 2 o 1 en las más chicas.
class KpiCardRow extends StatelessWidget {
  final List<Widget> cards;

  const KpiCardRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        final columns = ancho >= 1300
            ? 5
            : ancho >= 1050
            // Con 5 cards, 3 + 2 queda mejor que 4 + 1.
            ? (cards.length == 5 ? 3 : 4)
            : ancho >= 680
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 156,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

/// Card de cumplimiento con el criterio del inicio. En el anual, el acumulado
/// del año y cuántos puntos subió o bajó contra el mes anterior; en el
/// mensual, el del mes y la variación de horas por persona contra el anterior.
/// [color] reemplaza al del semáforo cuando la sección tiene su propio estado.
Widget cumplimientoKpiCard(
  BuildContext context, {
  required bool esAnual,
  required int anio,
  required int mes,
  required double porcentaje,
  VariacionCumplimiento? variacion,
  Color? color,
}) {
  final colorCard =
      color ?? EstadoSemaforo.desdePorcentaje(porcentaje).colores(context).texto;
  if (esAnual) {
    return DashboardKpiCard(
      title: 'CUMPLIMIENTO · AÑO $anio',
      value: formatearPorcentaje(porcentaje),
      suffix: 'acumulado del año',
      suffixDebajo: true,
      progress: (porcentaje / 100).clamp(0.0, 1.0),
      progressLabel: 'Acumulado del año',
      footer: '',
      badge: variacion?.puntos == null
          ? null
          : badgeVariacion(
              context,
              variacion!.puntos!,
              'pts',
              key: const Key('kpi_variacion_mes'),
            ),
      icon: Icons.event_available_outlined,
      color: colorCard,
      ayuda:
          'Horas válidas acumuladas en el año sobre la suma de los objetivos '
          'de los meses con datos. Los meses sin registros CRM ni LMS no '
          'cuentan. El recuadro muestra cuántos puntos cambió contra el '
          'acumulado hasta el mes anterior.',
    );
  }

  final anterior = variacion?.horasPersonaAnterior;
  return DashboardKpiCard(
    title: 'CUMPLIMIENTO · ${nombreMes(mes).toUpperCase()}',
    value: formatearPorcentaje(porcentaje),
    suffix: 'del objetivo del mes',
    progress: (porcentaje / 100).clamp(0.0, 1.0),
    progressLabel: variacion == null
        ? ''
        : '${variacion.horasPersona.toStringAsFixed(1)} h por persona',
    footer: anterior == null
        ? 'Sin datos del mes anterior'
        : 'Mes anterior: ${anterior.toStringAsFixed(1)} h',
    badge: variacion?.horas == null
        ? null
        : badgeVariacion(
            context,
            variacion!.horas!,
            'h',
            key: const Key('kpi_variacion_mes'),
          ),
    icon: Icons.event_available_outlined,
    color: colorCard,
    ayuda:
        'Horas válidas del mes sobre el objetivo del mes de los colaboradores '
        'elegibles, según su seniority. Cada persona suma como máximo su '
        'objetivo en cada categoría. El recuadro compara las horas por '
        'persona con el mes anterior.',
  );
}

/// Card de proyección a fin de año con el criterio del inicio: porcentaje de
/// la meta, variación contra el mes anterior, horas por persona, estado,
/// cuántos llegan y el ajuste necesario.
Widget proyeccionKpiCard(BuildContext context, ProyeccionAnual proyeccion) {
  final colores = proyeccion.estado.colores(context);
  final meta = proyeccion.meta;
  final cerrado = proyeccion.mesesRestantes == 0;

  return DashboardKpiCard(
    title: 'PROYECCIÓN ANUAL',
    value: formatearPorcentaje(proyeccion.porcentaje),
    suffix:
        '${proyeccion.proyeccion.toStringAsFixed(0)} / '
        '${meta.toStringAsFixed(0)} h por persona',
    suffixDebajo: true,
    progress: meta == 0 ? 1 : (proyeccion.proyeccion / meta).clamp(0.0, 1.0),
    progressLabel:
        '${proyeccion.estado.label} · ${proyeccion.llegan} de '
        '${proyeccion.colaboradores} ${cerrado ? 'cumplieron' : 'llegan'}',
    footer: cerrado
        ? 'Año cerrado: ${formatearPorcentaje(proyeccion.porcentaje)} de la meta'
        : proyeccion.ajuste > 0
        ? 'Ajuste: +${proyeccion.ajuste.toStringAsFixed(1)} h/mes por persona'
        : 'En camino a la meta',
    badge: proyeccion.variacionProyeccion == null
        ? null
        : badgeVariacion(
            context,
            proyeccion.variacionProyeccion!,
            'pts',
            key: const Key('kpi_variacion_proyeccion'),
          ),
    icon: switch (proyeccion.estado) {
      EstadoProyeccion.enCamino => Icons.trending_up,
      EstadoProyeccion.alcanzable => Icons.trending_flat,
      EstadoProyeccion.enRiesgo => Icons.trending_down,
    },
    color: colores.texto,
    ayuda:
        'Estimación a diciembre: lo acumulado más la tendencia de cada '
        'colaborador según sus meses con datos, sobre la meta del año. Las '
        'horas de una persona no cubren a otra, ni las de una categoría a '
        'otra. En camino: 100 % o más; Alcanzable: desde 85 %; En riesgo: '
        'menos de 85 %. El ajuste son las horas por persona y por mes que '
        'faltan para llegar.',
  );
}

/// "▲ +2.3 pts vs mes anterior" en verde, o "▼ -1.0 pts …" en rojo.
Widget badgeVariacion(
  BuildContext context,
  double valor,
  String unidad, {
  Key? key,
}) {
  final mejoro = valor >= 0;
  return DashboardKpiBadge(
    key: key,
    texto:
        '${mejoro ? '▲ +' : '▼ '}${valor.toStringAsFixed(1)} $unidad '
        'vs mes anterior',
    colores: mejoro ? context.colores.exito : context.colores.peligro,
  );
}

/// Recuadro chico dentro de una card: estado o variación.
class DashboardKpiBadge extends StatelessWidget {
  final String texto;
  final ParColores colores;

  const DashboardKpiBadge({
    super.key,
    required this.texto,
    required this.colores,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colores.fondo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colores.texto,
        ),
      ),
    );
  }
}

class DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;
  final double progress;
  final String progressLabel;
  final String footer;
  final String? secondaryText;

  /// Recuadro chico al lado del valor (por ejemplo, la variación del mes).
  final Widget? badge;

  /// Muestra el texto gris debajo del valor en lugar de al lado, para cuando
  /// no entra junto al recuadro.
  final bool suffixDebajo;
  final IconData icon;
  final Color color;

  /// Qué muestra la card y cómo se calcula. Aparece al pasar el mouse o
  /// tocar el ícono de información junto al título.
  final String? ayuda;

  const DashboardKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.suffix,
    required this.progress,
    required this.progressLabel,
    required this.footer,
    this.secondaryText,
    this.badge,
    this.suffixDebajo = false,
    required this.icon,
    required this.color,
    this.ayuda,
  });

  Widget _textoSuffix(BuildContext context) => Text(
    suffix,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 10, color: context.colorScheme.onSurfaceVariant),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: context.panel(sombra: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (ayuda case final ayuda?) ...[
                Tooltip(
                  message: ayuda,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 8),
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: context.colores.textoTenue,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(icon, size: 18, color: color),
            ],
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 3),
            Text(
              secondaryText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.colores.exito.texto,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              if (suffixDebajo)
                const Spacer()
              else
                Flexible(child: _textoSuffix(context)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Flexible(child: badge!),
              ],
            ],
          ),
          if (suffixDebajo) ...[
            const SizedBox(height: 2),
            _textoSuffix(context),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.colores.graficoPista,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  progressLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Quiénes cuentan en el período, para las cards de colaboradores.
const ayudaNominaElegible =
    'Colaboradores de la nómina elegibles en el período: ya habían ingresado '
    'y estaban activos al cierre del mes (en el anual, en algún mes con '
    'datos).';

const ayudaHorasValidasMes =
    'Horas que cuentan para el objetivo del mes: cursos de Negocio y Blandas '
    'finalizados en el LMS, con la carga horaria del catálogo, y horas de '
    'Libres y Dictado cargadas en el CRM. Cada persona suma como máximo su '
    'objetivo en cada categoría.';

const ayudaHorasValidasAnual =
    'Suma de las horas válidas de los meses con datos del año: cursos de '
    'Negocio y Blandas finalizados en el LMS y horas de Libres y Dictado del '
    'CRM. Un mes fuerte compensa uno flojo; cada persona suma como máximo su '
    'objetivo anual en cada categoría.';

/// Integrantes de un área o equipo y cuántos cumplieron.
String ayudaIntegrantes(String seccion) =>
    'Colaboradores elegibles $seccion en el período. Abajo, cuántos '
    'cumplieron el objetivo en todas sus categorías.';

/// Objetivo de horas de un área o equipo.
String ayudaObjetivo(String seccion) =>
    'Horas que $seccion debía hacer según el plan de formación para la '
    'seniority de cada integrante. En el anual, la suma de los objetivos de '
    'los meses con datos.';
