import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_finnegans/presentation/providers/auth_provider.dart';
import 'package:app_finnegans/presentation/providers/side_menu_providers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _anchoSideMenu = 260;

/// Mismo alto que `AppTopBar` y los top bars de cada pantalla, para que la
/// línea bajo el logo continúe exactamente la del top bar.
const double _altoHeader = 64;

/// Celeste pastel de la sidebar. La pestaña de ocultar/mostrar usa el mismo
/// color para leerse como parte del menú.
const Color _fondoSideMenu = Color(0xFFEAF3FE);

/// Bordes y divisores sobre el fondo celeste.
const Color _bordeSideMenu = Color(0xFFD2E3F8);

const Duration _duracionAnimacion = Duration(milliseconds: 220);

/// Transición de color del ítem activo del menú.
const Duration _duracionColor = Duration(milliseconds: 200);

class SideMenu extends ConsumerStatefulWidget {
  const SideMenu({super.key});

  @override
  ConsumerState<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends ConsumerState<SideMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animacion;

  // La pestaña sobresale del borde de la sidebar: si fuera hija del Row de la
  // pantalla quedaría pintada debajo del contenido y fuera del hit-test. Por
  // eso va en el overlay. Se ubica con overlayChildLayoutBuilder y no con un
  // CompositedTransformFollower: el Tooltip de la pestaña también usa ese
  // builder, y Flutter lo rompe si encuentra un follower entre él y el Overlay.
  final _pestana = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // Arranca en el estado actual: al navegar a otra pantalla no re-anima.
    _controller = AnimationController(
      vsync: this,
      duration: _duracionAnimacion,
      value: ref.read(sideMenuDesplegadoProvider) ? 1 : 0,
    );
    _animacion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _pestana.show();
  }

  @override
  void dispose() {
    _animacion.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(sideMenuDesplegadoProvider, (_, desplegado) {
      desplegado ? _controller.forward() : _controller.reverse();
    });
    final desplegado = ref.watch(sideMenuDesplegadoProvider);

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _pestana,
      overlayChildBuilder: (_, info) => _buildPestana(desplegado, info),
      child: AnimatedBuilder(
        animation: _animacion,
        // El contenido se arma siempre con el ancho completo y se recorta: la
        // sidebar se desliza como un cajón en lugar de comprimir los textos.
        builder: (context, contenido) => SizedBox(
          width: _anchoSideMenu * _animacion.value,
          child: Visibility(
            // Oculta del todo, los ítems no reciben foco ni quedan en la
            // semántica.
            visible: _animacion.value > 0,
            // Conserva el alto completo: con el SizedBox.shrink por defecto el
            // Row de la pantalla la centraría verticalmente y la pestaña
            // saltaría a la mitad de la altura al plegarse.
            replacement: const SizedBox(height: double.infinity),
            child: ClipRect(
              child: OverflowBox(
                minWidth: _anchoSideMenu,
                maxWidth: _anchoSideMenu,
                alignment: Alignment.centerRight,
                child: contenido,
              ),
            ),
          ),
        ),
        child: _buildContenido(context),
      ),
    );
  }

  /// Se vuelve a ejecutar en cada layout: `info` trae el tamaño y la posición
  /// de la sidebar en coordenadas del overlay, así la pestaña sigue el ancho
  /// animado y las transiciones de página.
  Widget _buildPestana(bool desplegado, OverlayChildLayoutInfo info) {
    final borde = MatrixUtils.transformPoint(
      info.childPaintTransform,
      Offset(info.childSize.width, 0),
    );

    // Pegada al borde derecho de la sidebar (o al borde de la pantalla cuando
    // está oculta). Se superpone 1px para tapar la línea del borde y que la
    // pestaña se vea como una continuación del menú.
    return Positioned(
      left: math.max(0, borde.dx - 1),
      top: borde.dy + _altoHeader + 16,
      child: _PestanaToggle(
        progreso: _animacion.value,
        desplegado: desplegado,
        onTap: () =>
            ref.read(sideMenuDesplegadoProvider.notifier).state = !desplegado,
      ),
    );
  }

  Widget _buildContenido(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final currentPath = uri.path;
    final requestedOrigin = uri.queryParameters['origen'];
    const validOrigins = {'dashboard', 'areas', 'equipos'};
    final origin = validOrigins.contains(requestedOrigin)
        ? requestedOrigin
        : null;

    bool isSelected(String section, String path) {
      if (origin != null) return origin == section;
      return currentPath.startsWith(path);
    }

    final auth = ref.watch(authControllerProvider);
    final mostrarAdmin = auth.esAdmin || !auth.enabled;

    return Container(
      width: _anchoSideMenu,
      decoration: const BoxDecoration(
        color: _fondoSideMenu,
        border: Border(right: BorderSide(color: _bordeSideMenu)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Logo
          Container(
            height: _altoHeader,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _bordeSideMenu)),
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
                // El padding superior baja el texto sin mover el logo (la
                // Row centra la columna, así que se desplaza la mitad).
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finnegans',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D53C3),
                        ),
                      ),
                      Text(
                        'Portal de formación interna',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
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
                /*
                _MenuItem(
                  icon: Icons.analytics_outlined,
                  label: 'Métricas',
                  isSelected: currentRoute.startsWith('/metricas'),
                  onTap: () {
                    context.push(
                      '/metricas',
                    ); // Navega a la pantalla de métricas
                  },
                ),
                */
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
                if (mostrarAdmin)
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
          const Divider(height: 1, color: _bordeSideMenu),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _MenuItem(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              isSelected: false,
              textColor: const Color(0xFFEF4444),
              iconColor: const Color(0xFFEF4444),
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
class _PestanaToggle extends StatefulWidget {
  static const double ancho = 22;
  static const double alto = 52;

  /// 1 = desplegada, 0 = oculta.
  final double progreso;
  final bool desplegado;
  final VoidCallback onTap;

  const _PestanaToggle({
    required this.progreso,
    required this.desplegado,
    required this.onTap,
  });

  @override
  State<_PestanaToggle> createState() => _PestanaToggleState();
}

class _PestanaToggleState extends State<_PestanaToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final mensaje = widget.desplegado ? 'Ocultar menú' : 'Mostrar menú';

    return Tooltip(
      message: mensaje,
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
              width: _PestanaToggle.ancho,
              height: _PestanaToggle.alto,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: _hover ? const Color(0xFFD6E7FD) : _fondoSideMenu,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10),
                        ),
                        border: Border.all(color: _bordeSideMenu),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x120D53C3),
                            blurRadius: 6,
                            offset: Offset(2, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: (1 - widget.progreso) * math.pi,
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            size: 20,
                            color: Color(0xFF0D53C3),
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
                      color: _hover ? const Color(0xFFD6E7FD) : _fondoSideMenu,
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
  final Color? textColor;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  static const _marca = Color(0xFF0D53C3);
  static final _radio = BorderRadius.circular(8);

  bool _hover = false;
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final seleccionado = widget.isSelected;
    final colorTexto =
        widget.textColor ?? (seleccionado ? _marca : const Color(0xFF334155));
    final colorIcono =
        widget.iconColor ?? (seleccionado ? _marca : const Color(0xFF64748B));

    // Sin ripple: el feedback es continuo. El fondo del ítem se desvanece entre
    // reposo, hover, presionado y seleccionado, y el texto y el ícono cambian de
    // color con la misma curva. Así nada aparece ni se borra de golpe.
    // Sobre el fondo celeste, el ítem activo es una "tarjeta" blanca y el hover
    // un blanco translúcido.
    final colorFondo = _presionado
        ? Colors.white.withValues(alpha: seleccionado ? 0.85 : 0.6)
        : seleccionado
        ? Colors.white
        : _hover
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (_) => setState(() => _presionado = true),
          onPointerUp: (_) => setState(() => _presionado = false),
          onPointerCancel: (_) => setState(() => _presionado = false),
          child: AnimatedContainer(
            duration: _duracionColor,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: _radio,
              boxShadow: seleccionado
                  ? const [
                      BoxShadow(
                        color: Color(0x140D53C3),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: _radio,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: colorIcono),
                duration: _duracionColor,
                curve: Curves.easeOut,
                builder: (context, iconoAnimado, _) =>
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: colorTexto),
                      duration: _duracionColor,
                      curve: Curves.easeOut,
                      builder: (context, textoAnimado, _) => ListTile(
                        shape: RoundedRectangleBorder(borderRadius: _radio),
                        onTap: widget.onTap,
                        dense: true,
                        // Sin ripple ni resaltados propios del ListTile.
                        splashColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: _marca.withValues(alpha: 0.08),
                        enableFeedback: false,
                        leading: Icon(
                          widget.icon,
                          size: 20,
                          color: iconoAnimado,
                        ),
                        title: Text(
                          widget.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: seleccionado
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: textoAnimado,
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
