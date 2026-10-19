import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_dropdown.dart';
import 'package:flutter/material.dart';

/// Barra de filtros común: buscador de texto, desplegables y "Limpiar".
/// Cada pantalla le pasa sus textos, desplegables y qué hacer al limpiar.
class FilterBar extends StatefulWidget {
  final String searchHint;
  final String searchText;
  final ValueChanged<String> onSearch;
  final List<FilterDropdown<Object?>> filters;
  final bool hasActiveFilters;
  final VoidCallback onClear;

  const FilterBar({
    super.key,
    required this.searchHint,
    required this.searchText,
    required this.onSearch,
    required this.hasActiveFilters,
    required this.onClear,
    this.filters = const [],
  });

  @override
  State<FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Los filtros pueden persistir al navegar: el texto arranca con el vigente.
    _controller = TextEditingController(text: widget.searchText);
  }

  @override
  void didUpdateWidget(covariant FilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mantiene el campo en sintonía cuando "Limpiar" vacía la búsqueda.
    if (widget.searchText != _controller.text) {
      _controller.text = widget.searchText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borde = context.colorScheme.outlineVariant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.panel(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final searchField = TextField(
            controller: _controller,
            onChanged: widget.onSearch,
            decoration: filtroInputDecoration(widget.searchHint, Icons.search),
          );
          final clearButton = OutlinedButton.icon(
            onPressed: widget.hasActiveFilters ? widget.onClear : null,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Limpiar'),
            // Colores y forma vienen del outlinedButtonTheme.
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: widget.hasActiveFilters
                    ? borde
                    : borde.withValues(alpha: 0.55),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
            ),
          );

          if (constraints.maxWidth < 800) {
            return Column(
              children: [
                searchField,
                for (final filter in widget.filters) ...[
                  const SizedBox(height: 12),
                  filter,
                ],
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: clearButton),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              for (final filter in widget.filters) ...[
                const SizedBox(width: 12),
                SizedBox(width: filter.width, child: filter),
              ],
              const SizedBox(width: 12),
              clearButton,
            ],
          );
        },
      ),
    );
  }
}
