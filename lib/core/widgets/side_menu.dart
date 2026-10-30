import 'dart:math' as math;

import 'package:app_finnegans/core/theme/app_theme.dart';
import 'package:app_finnegans/features/auth/domain/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/features/auth/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/core/widgets/side_menu_providers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _widthSideMenu = 260;

/// Mismo alto que `AppTopBar` y los top bars de cada pantalla, para que la
/// línea bajo el logo continúe exactamente la del top bar.
const double _heightHeader = 64;

const Duration _animationDuration = Duration(milliseconds: 220);

/// Transición de color del ítem activo del menú.
const Duration _durationColor = Duration(milliseconds: 200);

class SideMenu extends ConsumerStatefulWidget {
  const SideMenu({super.key});

  @override
  ConsumerState<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends ConsumerState<SideMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  // La pestaña sobresale del borde de la sidebar: si fuera hija del Row de la
  // pantalla quedaría pintada debajo del contenido y fuera del hit-test. Por
  // eso va en el overlay. Se ubica con overlayChildLayoutBuilder y no con un
  // CompositedTransformFollower: el Tooltip de la pestaña también usa ese
  // builder, y Flutter lo rompe si encuentra un follower entre él y el Overlay.
  final _tab = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // Arranca en el estado actual: al navegar a otra pantalla no re-anima.
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
      value: ref.read(sideMenuExpandedProvider) ? 1 : 0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _tab.show();
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sideMenuExpandedProvider, (_, expanded) {
      expanded ? _controller.forward() : _controller.reverse();
    });
    final isExpanded = ref.watch(sideMenuExpandedProvider);

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _tab,
      overlayChildBuilder: (_, info) => _buildTab(isExpanded, info),
      child: AnimatedBuilder(
        animation: _animation,
        // El contenido se arma siempre con el ancho completo y se recorta: la
        // sidebar se desliza como un cajón en lugar de comprimir los textos.
        builder: (context, content) => SizedBox(
          width: _widthSideMenu * _animation.value,
          child: Visibility(
            // Oculta del todo, los ítems no reciben foco ni quedan en la
            // semántica.
            visible: _animation.value > 0,
            // Conserva el alto completo: con el SizedBox.shrink por defecto el
            // Row de la pantalla la centraría verticalmente y la pestaña
            // saltaría a la mitad de la altura al plegarse.
            replacement: const SizedBox(height: double.infinity),
            child: ClipRect(
              child: OverflowBox(
                minWidth: _widthSideMenu,
                maxWidth: _widthSideMenu,
                alignment: Alignment.centerRight,
                child: content,
              ),
            ),
          ),
        ),
        child: _buildContent(context),
      ),
    );
  }

  /// Se vuelve a ejecutar en cada layout: `info` trae el tamaño y la posición
  /// de la sidebar en coordenadas del overlay, así la pestaña sigue el ancho
  /// animado y las transiciones de página.
  Widget _buildTab(bool expanded, OverlayChildLayoutInfo info) {
    final border = MatrixUtils.transformPoint(
      info.childPaintTransform,
      Offset(info.childSize.width, 0),
    );

    // Pegada al borde derecho de la sidebar (o al borde de la pantalla cuando
    // está oculta). Se superpone 1px para tapar la línea del borde y que la
    // pestaña se vea como una continuación del menú.
    return Positioned(
      left: math.max(0, border.dx - 1),
      top: border.dy + _heightHeader + 16,
      child: _TabToggle(
        progress: _animation.value,
        expanded: expanded,
        onTap: () =>
            ref.read(sideMenuExpandedProvider.notifier).state = !expanded,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final currentPath = uri.path;
    final requestedOrigin = uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos', 'certificaciones'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin
        : null;

    bool isSelected(String section, String path) {
      if (origin != null) return origin == section;
      return currentPath.startsWith(path);
    }

    final auth = ref.watch(authControllerProvider);
    // En modo local no hay roles: se ve todo, para poder probarlo.
    final manages = auth.canManage || !auth.enabled;
    final showAreas = !auth.enabled || auth.knownRole != UserRole.teamLead;
    final cs = context.colorScheme;
    final colors = context.colors;
    final border = BorderSide(color: colors.sidebarBorder);

    return Container(
      width: _widthSideMenu,
      decoration: BoxDecoration(
        color: colors.sidebarBackground,
        border: Border(right: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Logo
          Container(
            height: _heightHeader,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(border: Border(bottom: border)),
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
                // El padding superior baja el texto sin mover el logo (la
                // Row centra la columna, así que se desplaza la mitad).
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finnegans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        'Portal de formación interna',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Items de navegación
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              children: [
                _MenuItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Inicio',
                  isSelected: isSelected('dashboard', '/dashboard'),
                  onTap: () {
                    context.push(
                      '/dashboard',
                    ); // Navega a la pantalla de dashboard
                  },
                ),
                if (showAreas)
                  _MenuItem(
                    icon: Icons.account_tree_outlined,
                    label: 'Áreas',
                    isSelected: isSelected('areas', '/areas'),
                    onTap: () {
                      context.push('/areas'); // Navega a la pantalla de áreas
                    },
                  ),
                _MenuItem(
                  icon: Icons.group_work,
                  label: 'Equipos',
                  isSelected: isSelected('equipos', '/equipos'),
                  onTap: () {
                    context.push('/equipos'); // Navega a la pantalla de equipos
                  },
                ),
                _MenuItem(
                  icon: Icons.people_outline,
                  label: 'Empleados',
                  isSelected: isSelected('empleados', '/empleados'),
                  onTap: () {
                    context.push(
                      '/empleados',
                    ); // Navega a la pantalla de empleados
                  },
                ),

                _MenuItem(
                  icon: Icons.school_outlined,
                  label: 'Cursos',
                  isSelected: isSelected('cursos', '/cursos'),
                  onTap: () {
                    context.push('/cursos'); // Navega a la pantalla de cursos
                  },
                ),
                _MenuItem(
                  icon: Icons.assignment_outlined,
                  label: 'Carga de horas CRM',
                  isSelected: isSelected('cursadas', '/cursadas'),
                  onTap: () {
                    context.push(
                      '/cursadas',
                    ); // Navega a la pantalla de cursadas
                  },
                ),
                _MenuItem(
                  icon: Icons.verified_outlined,
                  label: 'Certificaciones LMS',
                  isSelected: isSelected('certificaciones', '/certificaciones'),
                  onTap: () => context.push('/certificaciones'),
                ),
                if (manages)
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Configuración',
                    isSelected: isSelected('configuracion', '/configuracion'),
                    onTap: () {
                      context.push(
                        '/configuracion',
                      ); // Navega a la pantalla de configuración
                    },
                  ),
                if (manages)
                  _MenuItem(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Panel de administrador',
                    isSelected: isSelected('admin', '/admin'),
                    onTap: () {
                      context.push('/admin');
                    },
                  ),
              ],
            ),
          ),
          // Logout
          Divider(height: 1, color: colors.sidebarBorder),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _MenuItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              isSelected: false,
              color: cs.error,
              onTap: () async {
                final auth = ref.read(authControllerProvider);
                try {
                  await auth.signOut();
                  if (context.mounted) {
                    context.go(auth.enabled ? '/login' : '/');
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No se pudo completar el cierre de sesión.',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pestaña vertical que sale del borde derecho de la sidebar, del mismo color
/// y sin línea divisoria, como la manija de un cajón. La flecha gira junto con
/// la animación: apunta a la izquierda desplegada y a la derecha oculta.
class _TabToggle extends StatefulWidget {
  static const double width = 22;
  static const double height = 52;

  /// 1 = desplegada, 0 = oculta.
  final double progress;
  final bool expanded;
  final VoidCallback onTap;

  const _TabToggle({
    required this.progress,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<_TabToggle> createState() => _TabToggleState();
}

class _TabToggleState extends State<_TabToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.expanded ? 'Ocultar menú' : 'Mostrar menú';
    final colors = context.colors;
    final background = _hover ? colors.sidebarHover : colors.sidebarBackground;
    final brand = context.colorScheme.primary;

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            key: const Key('side_menu_toggle'),
            onTap: widget.onTap,
            child: SizedBox(
              width: _TabToggle.width,
              height: _TabToggle.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10),
                        ),
                        border: Border.all(color: colors.sidebarBorder),
                        boxShadow: [
                          BoxShadow(
                            color: brand.withValues(alpha: 0.07),
                            blurRadius: 6,
                            offset: const Offset(2, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: (1 - widget.progress) * math.pi,
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 20,
                            color: brand,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tapa el borde izquierdo de la pestaña y el borde derecho de
                  // la sidebar justo detrás: sin esa línea, la pestaña se lee
                  // como parte del menú y no como un botón suelto.
                  Positioned(
                    left: 0,
                    top: 1,
                    bottom: 1,
                    width: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: background,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Color fijo de texto e ícono (p. ej. "Cerrar sesión" en rojo); si es
  /// null se usan los del menú según el estado.
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  static final _radius = BorderRadius.circular(8);

  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final colors = context.colors;
    final brand = cs.primary;
    final selected = widget.isSelected;
    final textColor =
        widget.color ?? (selected ? brand : colors.intermediateText);
    final iconColor = widget.color ?? (selected ? brand : cs.onSurfaceVariant);

    // Sin ripple: el feedback es continuo. El fondo del ítem se desvanece entre
    // reposo, hover, presionado y seleccionado, y el texto y el ícono cambian de
    // color con la misma curva. Así nada aparece ni se borra de golpe.
    // Sobre el fondo del menú, el ítem activo es una "tarjeta" y el hover la
    // misma tarjeta translúcida.
    final active = colors.sidebarActive;
    final backgroundColor = _pressed
        ? active.withValues(alpha: selected ? 0.85 : 0.6)
        : selected
        ? active
        : _hover
        ? active.withValues(alpha: 0.55)
        : active.withValues(alpha: 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: _durationColor,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: _radius,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: brand.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: _radius,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: iconColor),
                duration: _durationColor,
                curve: Curves.easeOut,
                builder: (context, animatedIcon, _) =>
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: textColor),
                      duration: _durationColor,
                      curve: Curves.easeOut,
                      builder: (context, animatedText, _) => ListTile(
                        shape: RoundedRectangleBorder(borderRadius: _radius),
                        onTap: widget.onTap,
                        dense: true,
                        // Sin ripple ni resaltados propios del ListTile.
                        splashColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: brand.withValues(alpha: 0.08),
                        enableFeedback: false,
                        leading: Icon(
                          widget.icon,
                          size: 20,
                          color: animatedIcon,
                        ),
                        title: Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: animatedText,
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
