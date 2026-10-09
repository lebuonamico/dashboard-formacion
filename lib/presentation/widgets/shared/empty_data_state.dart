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

  const EmptyDataState.periodoSinDatos({
    super.key,
    required String periodo,
    this.icon = Icons.event_busy_outlined,
    this.compact = false,
  }) : title = 'No hay datos cargados para $periodo.',
       message =
           'Probá otro período o cargá información CRM/LMS para evaluarlo.';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 24 : 72,
        horizontal: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: const Color(0xFF64748B)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }
}
