import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:app_finnegans/core/widgets/app_back_button.dart';
import 'package:app_finnegans/features/auth/presentation/widgets/user_avatar.dart';

class AppTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const AppTopBar({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: onBack == null ? 24 : 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            // Flecha para volver a la pantalla anterior.
            AppBackButton(onPressed: onBack!),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          const UserAvatar(),
        ],
      ),
    );
  }
}
