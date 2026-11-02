import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CountBadge extends StatelessWidget {
  final int count;

  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.primary,
        ),
      ),
    );
  }
}
