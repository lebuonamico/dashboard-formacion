import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/filter_bar.dart';

class AdminFilters extends StatelessWidget {
  final bool hayFiltrosActivos;
  final VoidCallback onLimpiar;

  const AdminFilters({
    super.key,
    required this.hayFiltrosActivos,
    required this.onLimpiar,
  });

  @override
  Widget build(BuildContext context) => FilterBar(
    scope: 'admin',
    hasActiveFilters: hayFiltrosActivos,
    onClear: onLimpiar,
  );
}
