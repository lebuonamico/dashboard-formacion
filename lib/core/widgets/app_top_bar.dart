import 'package:app_finnegans/core/layout/window_size.dart';
import 'package:app_finnegans/core/navigation/modal_navigation_scope.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_finnegans/core/widgets/app_back_button.dart';
import 'package:app_finnegans/features/auth/presentation/widgets/user_avatar.dart';

/// Bar at the top of every screen. Below 840 px, sections show the button
/// that opens the modal menu (details keep their back arrow); on phones the
/// title is smaller and the account shows only the photo.
class AppTopBar extends StatelessWidget {
  final String title;
  final String? backTo;

  const AppTopBar({super.key, required this.title, this.backTo});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final compact = context.windowSize == WindowSize.compact;
    final openMenu = backTo == null
        ? ModalNavigationScope.maybeOpenMenuOf(context)
        : null;
    final edge = compact ? 16.0 : (backTo == null ? 24.0 : 16.0);

    return Container(
      height: 64,
      padding: EdgeInsets.only(
        // The icon buttons bring their own padding.
        left: openMenu != null ? 8 : edge,
        right: compact ? 8 : edge,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          if (openMenu != null) ...[
            IconButton(
              key: const Key('modal_menu_open'),
              tooltip: 'Abrir menú',
              icon: const Icon(Icons.menu),
              onPressed: openMenu,
            ),
            const SizedBox(width: 4),
          ],
          if (backTo case final parent?) ...[
            AppBackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(parent),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (compact
                          ? context.textTheme.titleMedium
                          : context.textTheme.titleLarge)
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
            ),
          ),
          UserAvatar(showName: !compact),
        ],
      ),
    );
  }
}
