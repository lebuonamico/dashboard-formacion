import 'package:flutter/material.dart';
import 'package:app_finnegans/presentation/widgets/shared/app_back_button.dart';
import 'package:app_finnegans/presentation/widgets/shared/user_avatar.dart';

class AppTopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const AppTopBar({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: onBack == null ? 24 : 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const UserAvatar(),
        ],
      ),
    );
  }
}
