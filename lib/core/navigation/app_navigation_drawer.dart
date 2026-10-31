import 'package:app_finnegans/core/navigation/app_destination.dart';
import 'package:app_finnegans/core/navigation/side_menu_provider.dart';
import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/core/widgets/feedback.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const expandedDrawerWidth = 260.0;
const collapsedDrawerWidth = 56.0;
const drawerHeaderHeight = 64.0;

class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sideMenuExpandedProvider);
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: expanded ? expandedDrawerWidth : collapsedDrawerWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colors.sidebarBorder)),
      ),
      child: Material(
        color: colors.sidebarBackground,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: expanded ? expandedDrawerWidth : collapsedDrawerWidth,
            maxWidth: expanded ? expandedDrawerWidth : collapsedDrawerWidth,
            child: expanded ? const _ExpandedMenu() : const _CollapsedMenu(),
          ),
        ),
      ),
    );
  }
}

class _ExpandedMenu extends ConsumerWidget {
  const _ExpandedMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final destinations = visibleDestinations(
      canManage: auth.canManage || !auth.enabled,
      isTeamLead: auth.enabled && auth.knownRole == UserRole.teamLead,
    );
    final selectedIndex = selectedDestinationIndex(
      GoRouterState.of(context).uri,
      destinations,
    );

    return Column(
      children: [
        const _DrawerHeader(),
        Expanded(
          child: NavigationDrawer(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) =>
                context.go(destinations[index].path),
            children: [
              const SizedBox(height: 12),
              for (final destination in destinations)
                NavigationDrawerDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: context.colors.sidebarBorder),
        const _LogoutTile(),
      ],
    );
  }
}

class _DrawerHeader extends ConsumerWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    return Container(
      height: drawerHeaderHeight,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.sidebarBorder)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo_finnegans.png',
              width: 36,
              height: 36,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finnegans',
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                Text(
                  'Portal de formación interna',
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('side_menu_toggle'),
            tooltip: 'Ocultar menú',
            icon: const Icon(Icons.chevron_left),
            onPressed: ref.read(sideMenuExpandedProvider.notifier).toggle,
          ),
        ],
      ),
    );
  }
}

class _CollapsedMenu extends ConsumerWidget {
  const _CollapsedMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      height: drawerHeaderHeight,
      child: Center(
        child: IconButton(
          key: const Key('side_menu_toggle'),
          tooltip: 'Mostrar menú',
          icon: const Icon(Icons.menu),
          onPressed: ref.read(sideMenuExpandedProvider.notifier).toggle,
        ),
      ),
    ),
  );
}

class _LogoutTile extends ConsumerWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = context.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(Icons.logout_rounded, color: error),
        title: Text('Cerrar sesión', style: TextStyle(color: error)),
        onTap: () => _signOut(context, ref),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider);
    try {
      await auth.signOut();
      if (context.mounted) context.go(auth.enabled ? '/login' : '/');
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, 'No se pudo completar el cierre de sesión.');
      }
    }
  }
}
