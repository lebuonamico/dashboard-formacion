import 'package:app_finnegans/domain/modelos/carga_de_horas_crm.dart';
import 'package:app_finnegans/domain/modelos/cumplimiento_empleado.dart';
import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/providers/metricas_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardKpiGrid extends StatelessWidget {
  final AsyncValue<List<CumplimientoEmpleado>> cumplimientosAsync;
  final AsyncValue<List<CargaDeHorasCRM>> cargasAsync;
  final AsyncValue<List<SemaforoAreaViewModel>> areasAsync;
  final AsyncValue<List<EquipoGlobalViewModel>> equiposAsync;

  const DashboardKpiGrid({
    super.key,
    required this.cumplimientosAsync,
    required this.cargasAsync,
    required this.areasAsync,
    required this.equiposAsync,
  });

  @override
  Widget build(BuildContext context) {
    if (cumplimientosAsync.isLoading ||
        cargasAsync.isLoading ||
        areasAsync.isLoading ||
        equiposAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final asyncValues = [
      cumplimientosAsync,
      cargasAsync,
      areasAsync,
      equiposAsync,
    ];
    final error = asyncValues.where((value) => value.hasError).firstOrNull;
    if (error != null) return Text('Error: ${error.error}');

    final cumplimientos = cumplimientosAsync.value ?? [];
    final cargas = cargasAsync.value ?? [];
    final areas = areasAsync.value ?? [];
    final equipos = equiposAsync.value ?? [];
    if (cumplimientos.isEmpty) return const SizedBox.shrink();

    final totalEmpleados = cumplimientos.length;
    final totalHoras = cumplimientos.fold<double>(
      0,
      (total, item) => total + item.totalHorasCompletadas,
    );
    final promedioHoras = totalHoras / totalEmpleados;
    final promedioCumplimiento =
        cumplimientos
            .map((item) => item.porcentajeTotal)
            .reduce((a, b) => a + b) /
        totalEmpleados;
    final empleadosTomaronCurso = cargas
        .where((carga) => !carga.esDictada)
        .map((carga) => carga.empleadoLegajo)
        .toSet()
        .length;
    final latestDate = cargas.isEmpty
        ? null
        : cargas
              .map((carga) => carga.fecha)
              .reduce((latest, date) => date.isAfter(latest) ? date : latest);
    final horasUltimoMes = latestDate == null
        ? 0.0
        : cargas
              .where(
                (carga) =>
                    carga.fecha.year == latestDate.year &&
                    carga.fecha.month == latestDate.month,
              )
              .fold<double>(0, (total, carga) => total + carga.horasTotales);
    final metaUltimoMes = totalEmpleados * 8.0;

    final cards = [
      DashboardKpiCard(
        title: 'COLABORADORES',
        value: '$totalEmpleados',
        suffix: ' nómina activa',
        progress: 1,
        progressLabel: '${areas.length} áreas',
        footer: '${equipos.length} equipos',
        icon: Icons.groups_outlined,
        color: const Color(0xFF2563EB),
      ),
      DashboardKpiCard(
        title: 'HORAS CARGADAS ÚLTIMO MES',
        value: '${horasUltimoMes.toStringAsFixed(1)} h',
        suffix: '/ Meta: ${metaUltimoMes.toStringAsFixed(0)} h',
        progress: metaUltimoMes == 0
            ? 0
            : (horasUltimoMes / metaUltimoMes).clamp(0.0, 1.0),
        progressLabel: 'Meta: 8 h por colaborador',
        footer:
            '${(metaUltimoMes - horasUltimoMes).clamp(0, double.infinity).toStringAsFixed(1)} h restantes',
        icon: Icons.schedule_outlined,
        color: const Color(0xFF2563EB),
      ),
      DashboardKpiCard(
        title: 'COLABORADORES CAPACITÁNDOSE',
        value: '$empleadosTomaronCurso',
        suffix: ' de $totalEmpleados',
        progress: (empleadosTomaronCurso / totalEmpleados).clamp(0.0, 1.0),
        progressLabel:
            '${(empleadosTomaronCurso / totalEmpleados * 100).toStringAsFixed(0)}% de la nómina',
        footer: '${totalEmpleados - empleadosTomaronCurso} sin cursos tomados',
        icon: Icons.school_outlined,
        color: const Color(0xFF009B61),
      ),
      DashboardKpiCard(
        title: 'PROYECCIÓN ANUAL',
        value: '${(promedioHoras * 12).toStringAsFixed(0)} h',
        suffix: '/ Meta: 96 h',
        progress: (promedioHoras * 12 / 96).clamp(0.0, 1.0),
        progressLabel:
            'Ritmo actual: ${promedioHoras.toStringAsFixed(1)} h/mes',
        footer:
            'Cumplimiento promedio ${promedioCumplimiento.toStringAsFixed(0)}%',
        icon: Icons.trending_up,
        color: const Color(0xFF2563EB),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 148,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
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
  final IconData icon;
  final Color color;

  const DashboardKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.suffix,
    required this.progress,
    required this.progressLabel,
    required this.footer,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD5DCEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  suffix,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5ECFA),
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
                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
