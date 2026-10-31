import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// La pantalla calcula las páginas y este widget sólo muestra el estado y botones.
class ResultsPagination extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final int from;
  final int until;
  final int totalResults;
  final String resultsLabel;
  final IconData icon;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const ResultsPagination({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.from,
    required this.until,
    required this.totalResults,
    required this.resultsLabel,
    required this.icon,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final textStyle = context.textTheme.bodySmall!.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: context.panel().copyWith(color: cs.surfaceContainer),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 20,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 9),
              Text(
                'Mostrando $from-$until de $totalResults $resultsLabel',
                style: textStyle,
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Leandro: llama a IconButton.filledTonal con onPrevious para solicitar la página anterior.
              IconButton.filledTonal(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Página anterior',
              ),
              const SizedBox(width: 12),
              Text(
                'Página ${currentPage + 1} de $pageCount',
                style: textStyle.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              // Leandro: llama a IconButton.filledTonal con onNext para solicitar la página siguiente.
              IconButton.filledTonal(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Página siguiente',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
