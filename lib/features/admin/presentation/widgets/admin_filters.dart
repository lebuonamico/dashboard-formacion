import 'package:flutter/material.dart';
import 'package:app_finnegans/core/data_filters/filter_bar.dart';

class AdminFilters extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClear;

  const AdminFilters({
    super.key,
    required this.hasActiveFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => FilterBar(
    scope: 'admin',
    hasActiveFilters: hasActiveFilters,
    onClear: onClear,
  );
}
