import 'package:app_finnegans/presentation/providers/equipos_providers.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipo_card.dart';
import 'package:app_finnegans/presentation/widgets/equipos/equipos_styles.dart';
import 'package:flutter/material.dart';

/// Leandro: Recibe los equipos filtrados y llama a EquipoCard por cada resultado.
class EquiposResults extends StatelessWidget {
  final List<EquipoGlobalViewModel> equipos;
  final int totalEquipos;

  const EquiposResults({
    super.key,
    required this.equipos,
    required this.totalEquipos,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Equipos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: equiposInk,
              ),
            ),
            const SizedBox(width: 8),
            _CountBadge(count: equipos.length),
            const Spacer(),
            Text(
              'Mostrando ${equipos.length} de $totalEquipos',
              style: const TextStyle(fontSize: 13, color: equiposMuted),
            ),
          ],
        ),
        const SizedBox(height: 13),
        // Leandro: Sin coincidencias cambia sólo esta sección; los KPI siguen visibles.
        if (equipos.isEmpty)
          const _EmptySearch()
        else
          _TeamsGrid(equipos: equipos),
      ],
    );
  }
}

// Leandro: Contador de equipos visibles después de aplicar filtros.
class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: equiposBrand,
        ),
      ),
    );
  }
}

// Leandro: Convierte la lista filtrada en una grilla de EquipoCard.
class _TeamsGrid extends StatelessWidget {
  final List<EquipoGlobalViewModel> equipos;

  const _TeamsGrid({required this.equipos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Leandro: El desplazamiento lo maneja el ListView principal de EquiposScreen.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 410,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 252,
      ),
      itemCount: equipos.length,
      itemBuilder: (context, index) => EquipoCard(equipo: equipos[index]),
    );
  }
}

// Leandro: Se muestra cuando los filtros no encuentran coincidencias.
class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: equiposPanelDecoration(),
      child: const Column(
        children: [
          Icon(Icons.search_off_outlined, size: 30, color: equiposMuted),
          SizedBox(height: 10),
          Text(
            'No encontramos equipos con esos filtros.',
            style: TextStyle(fontWeight: FontWeight.w600, color: equiposInk),
          ),
          SizedBox(height: 4),
          Text(
            'Probá con otra búsqueda, área o estado.',
            style: TextStyle(fontSize: 13, color: equiposMuted),
          ),
        ],
      ),
    );
  }
}
