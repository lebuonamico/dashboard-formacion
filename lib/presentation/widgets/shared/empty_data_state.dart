import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class EmptyDataState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  final bool compact;

  const EmptyDataState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.compact = false,
  });

  const EmptyDataState.periodWithoutData({
    super.key,
    required String period,
    this.icon = Icons.event_busy_outlined,
    this.compact = false,
  }) : title = 'No hay datos cargados para $period.',
       message =
           'Probá otro período o cargá información CRM/LMS para evaluarlo.';

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 24 : 72,
        horizontal: 24,
      ),
      decoration: context.panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
