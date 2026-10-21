import 'package:app_finnegans/domain/modelos/seniority.dart';
import 'package:app_finnegans/domain/modelos/tipo_curso.dart';
import 'package:flutter/material.dart';

/// Color de texto (o ícono) y su fondo, para chips, badges y avisos.
@immutable
class ParColores {
  final Color texto;
  final Color fondo;

  const ParColores(this.texto, this.fondo);

  static ParColores lerp(ParColores a, ParColores b, double t) => ParColores(
    Color.lerp(a.texto, b.texto, t)!,
    Color.lerp(a.fondo, b.fondo, t)!,
  );
}

/// Colores propios de la app que el [ColorScheme] de Material no cubre:
/// estados del semáforo, categorías de curso, seniority, side menu y el
/// asistente IA. Los colores de superficie, texto, borde y marca salen del
/// [ColorScheme] (ver `AppTheme`).
///
/// Es el único lugar, junto con `app_theme.dart`, donde se escriben colores
/// literales.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Texto entre `onSurface` (títulos) y `onSurfaceVariant` (secundario).
  final Color textoIntermedio;

  /// Texto de menor jerarquía: placeholders, deshabilitados, ejes.
  final Color textoTenue;

  final ParColores exito;
  final ParColores advertencia;
  final ParColores peligro;

  /// Chips o fichas sin estado (por ejemplo una categoría no requerida).
  final ParColores neutro;

  final ParColores negocio;
  final ParColores blandas;
  final ParColores exploracion;
  final ParColores dictado;

  final ParColores trainee;
  final ParColores junior;
  final ParColores semisenior;
  final ParColores senior;
  final ParColores manager;

  /// Pista de fondo de donuts y barras de progreso.
  final Color graficoPista;

  /// Acentos decorativos para íconos de KPI que no representan un estado.
  final Color acentoCian;
  final Color acentoVioleta;

  final Color sidebarFondo;
  final Color sidebarBorde;
  final Color sidebarHover;
  final Color sidebarActivo;

  /// Acento violeta del asistente IA (foco, viñetas, código).
  final ParColores ia;
  final List<Color> iaGradienteEncabezado;
  final List<Color> iaGradienteSimbolo;
  final List<Color> iaGradienteEnviar;
  final List<Color> iaBurbujaUsuario;

  /// Texto e íconos sobre los gradientes del asistente.
  final Color sobreGradiente;

  const AppColors({
    required this.textoIntermedio,
    required this.textoTenue,
    required this.exito,
    required this.advertencia,
    required this.peligro,
    required this.neutro,
    required this.negocio,
    required this.blandas,
    required this.exploracion,
    required this.dictado,
    required this.trainee,
    required this.junior,
    required this.semisenior,
    required this.senior,
    required this.manager,
    required this.graficoPista,
    required this.acentoCian,
    required this.acentoVioleta,
    required this.sidebarFondo,
    required this.sidebarBorde,
    required this.sidebarHover,
    required this.sidebarActivo,
    required this.ia,
    required this.iaGradienteEncabezado,
    required this.iaGradienteSimbolo,
    required this.iaGradienteEnviar,
    required this.iaBurbujaUsuario,
    required this.sobreGradiente,
  });

  static const light = AppColors(
    textoIntermedio: Color(0xFF334155),
    textoTenue: Color(0xFF94A3B8),
    exito: ParColores(Color(0xFF15803D), Color(0xFFDCFCE7)),
    advertencia: ParColores(Color(0xFFB45309), Color(0xFFFEF3C7)),
    // Rojo 700: el 600 sobre su fondo rosado no llegaba al contraste AA.
    peligro: ParColores(Color(0xFFB91C1C), Color(0xFFFEE2E2)),
    neutro: ParColores(Color(0xFF475569), Color(0xFFF1F5F9)),
    negocio: ParColores(Color(0xFF1D4ED8), Color(0xFFEFF6FF)),
    blandas: ParColores(Color(0xFF7E22CE), Color(0xFFF3E8FF)),
    exploracion: ParColores(Color(0xFF047857), Color(0xFFECFDF5)),
    dictado: ParColores(Color(0xFFC2410C), Color(0xFFFFF7ED)),
    trainee: ParColores(Color(0xFF475569), Color(0xFFF1F5F9)),
    junior: ParColores(Color(0xFF0369A1), Color(0xFFE0F2FE)),
    semisenior: ParColores(Color(0xFF6D28D9), Color(0xFFEDE9FE)),
    senior: ParColores(Color(0xFF0D53C3), Color(0xFFDBEAFE)),
    manager: ParColores(Color(0xFF0F766E), Color(0xFFCCFBF1)),
    graficoPista: Color(0xFFE5ECFA),
    acentoCian: Color(0xFF0E7490),
    acentoVioleta: Color(0xFF6941C6),
    sidebarFondo: Color(0xFFEAF3FE),
    sidebarBorde: Color(0xFFD2E3F8),
    sidebarHover: Color(0xFFD6E7FD),
    sidebarActivo: Color(0xFFFFFFFF),
    ia: ParColores(Color(0xFF6451D8), Color(0xFFF0F3FC)),
    iaGradienteEncabezado: [
      Color(0xFF122E62),
      Color(0xFF283574),
      Color(0xFF514197),
    ],
    iaGradienteSimbolo: [
      Color(0xFF2463CC),
      Color(0xFF7755CC),
      Color(0xFF37B8CB),
    ],
    iaGradienteEnviar: [Color(0xFF3462CE), Color(0xFF7954D6)],
    iaBurbujaUsuario: [Color(0xFFEDF3FF), Color(0xFFEEEDFD)],
    sobreGradiente: Color(0xFFFFFFFF),
  );

  /// En oscuro los fondos de chips son el color del texto con baja opacidad:
  /// los pasteles del modo claro brillan demasiado sobre superficies oscuras.
  static const dark = AppColors(
    textoIntermedio: Color(0xFFCBD5E1),
    textoTenue: Color(0xFF64748B),
    exito: ParColores(Color(0xFF4ADE80), Color(0x2622C55E)),
    advertencia: ParColores(Color(0xFFFBBF24), Color(0x26F59E0B)),
    peligro: ParColores(Color(0xFFF87171), Color(0x26EF4444)),
    neutro: ParColores(Color(0xFFCBD5E1), Color(0x2694A3B8)),
    negocio: ParColores(Color(0xFF93C5FD), Color(0x263B82F6)),
    blandas: ParColores(Color(0xFFD8B4FE), Color(0x26A855F7)),
    exploracion: ParColores(Color(0xFF6EE7B7), Color(0x2610B981)),
    dictado: ParColores(Color(0xFFFDBA74), Color(0x26F97316)),
    trainee: ParColores(Color(0xFFCBD5E1), Color(0x2694A3B8)),
    junior: ParColores(Color(0xFF7DD3FC), Color(0x260EA5E9)),
    semisenior: ParColores(Color(0xFFC4B5FD), Color(0x268B5CF6)),
    senior: ParColores(Color(0xFF93C5FD), Color(0x263B82F6)),
    manager: ParColores(Color(0xFF5EEAD4), Color(0x2614B8A6)),
    graficoPista: Color(0xFF263248),
    acentoCian: Color(0xFF22D3EE),
    acentoVioleta: Color(0xFFB39DFF),
    sidebarFondo: Color(0xFF0E1A30),
    sidebarBorde: Color(0xFF1E2D4A),
    sidebarHover: Color(0xFF182A4A),
    sidebarActivo: Color(0xFF1F3A66),
    ia: ParColores(Color(0xFFA99BFF), Color(0xFF1A2238)),
    iaGradienteEncabezado: [
      Color(0xFF122E62),
      Color(0xFF283574),
      Color(0xFF514197),
    ],
    iaGradienteSimbolo: [
      Color(0xFF2463CC),
      Color(0xFF7755CC),
      Color(0xFF37B8CB),
    ],
    iaGradienteEnviar: [Color(0xFF3462CE), Color(0xFF7954D6)],
    iaBurbujaUsuario: [Color(0xFF1C2B4D), Color(0xFF29254F)],
    sobreGradiente: Color(0xFFFFFFFF),
  );

  ParColores categoria(TipoCurso tipo) => switch (tipo) {
    TipoCurso.habilidadesDeNegocio => negocio,
    TipoCurso.habilidadesBlandas => blandas,
    TipoCurso.libresExploracion => exploracion,
    TipoCurso.dictadoCapacitaciones => dictado,
  };

  ParColores nivel(Seniority seniority) => switch (seniority) {
    Seniority.trainee => trainee,
    Seniority.junior1 || Seniority.junior2 || Seniority.junior3 => junior,
    Seniority.semisenior1 ||
    Seniority.semisenior2 ||
    Seniority.semisenior3 => semisenior,
    Seniority.senior1 || Seniority.senior2 || Seniority.senior3 => senior,
    Seniority.manager => manager,
  };

  @override
  AppColors copyWith({
    Color? textoIntermedio,
    Color? textoTenue,
    ParColores? exito,
    ParColores? advertencia,
    ParColores? peligro,
    ParColores? neutro,
    ParColores? negocio,
    ParColores? blandas,
    ParColores? exploracion,
    ParColores? dictado,
    ParColores? trainee,
    ParColores? junior,
    ParColores? semisenior,
    ParColores? senior,
    ParColores? manager,
    Color? graficoPista,
    Color? acentoCian,
    Color? acentoVioleta,
    Color? sidebarFondo,
    Color? sidebarBorde,
    Color? sidebarHover,
    Color? sidebarActivo,
    ParColores? ia,
    List<Color>? iaGradienteEncabezado,
    List<Color>? iaGradienteSimbolo,
    List<Color>? iaGradienteEnviar,
    List<Color>? iaBurbujaUsuario,
    Color? sobreGradiente,
  }) => AppColors(
    textoIntermedio: textoIntermedio ?? this.textoIntermedio,
    textoTenue: textoTenue ?? this.textoTenue,
    exito: exito ?? this.exito,
    advertencia: advertencia ?? this.advertencia,
    peligro: peligro ?? this.peligro,
    neutro: neutro ?? this.neutro,
    negocio: negocio ?? this.negocio,
    blandas: blandas ?? this.blandas,
    exploracion: exploracion ?? this.exploracion,
    dictado: dictado ?? this.dictado,
    trainee: trainee ?? this.trainee,
    junior: junior ?? this.junior,
    semisenior: semisenior ?? this.semisenior,
    senior: senior ?? this.senior,
    manager: manager ?? this.manager,
    graficoPista: graficoPista ?? this.graficoPista,
    acentoCian: acentoCian ?? this.acentoCian,
    acentoVioleta: acentoVioleta ?? this.acentoVioleta,
    sidebarFondo: sidebarFondo ?? this.sidebarFondo,
    sidebarBorde: sidebarBorde ?? this.sidebarBorde,
    sidebarHover: sidebarHover ?? this.sidebarHover,
    sidebarActivo: sidebarActivo ?? this.sidebarActivo,
    ia: ia ?? this.ia,
    iaGradienteEncabezado: iaGradienteEncabezado ?? this.iaGradienteEncabezado,
    iaGradienteSimbolo: iaGradienteSimbolo ?? this.iaGradienteSimbolo,
    iaGradienteEnviar: iaGradienteEnviar ?? this.iaGradienteEnviar,
    iaBurbujaUsuario: iaBurbujaUsuario ?? this.iaBurbujaUsuario,
    sobreGradiente: sobreGradiente ?? this.sobreGradiente,
  );

  /// Interpola todos los colores: el cambio claro/oscuro se anima en lugar
  /// de saltar.
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    ParColores p(ParColores a, ParColores b) => ParColores.lerp(a, b, t);
    List<Color> l(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) c(a[i], b[i]),
    ];

    return AppColors(
      textoIntermedio: c(textoIntermedio, other.textoIntermedio),
      textoTenue: c(textoTenue, other.textoTenue),
      exito: p(exito, other.exito),
      advertencia: p(advertencia, other.advertencia),
      peligro: p(peligro, other.peligro),
      neutro: p(neutro, other.neutro),
      negocio: p(negocio, other.negocio),
      blandas: p(blandas, other.blandas),
      exploracion: p(exploracion, other.exploracion),
      dictado: p(dictado, other.dictado),
      trainee: p(trainee, other.trainee),
      junior: p(junior, other.junior),
      semisenior: p(semisenior, other.semisenior),
      senior: p(senior, other.senior),
      manager: p(manager, other.manager),
      graficoPista: c(graficoPista, other.graficoPista),
      acentoCian: c(acentoCian, other.acentoCian),
      acentoVioleta: c(acentoVioleta, other.acentoVioleta),
      sidebarFondo: c(sidebarFondo, other.sidebarFondo),
      sidebarBorde: c(sidebarBorde, other.sidebarBorde),
      sidebarHover: c(sidebarHover, other.sidebarHover),
      sidebarActivo: c(sidebarActivo, other.sidebarActivo),
      ia: p(ia, other.ia),
      iaGradienteEncabezado: l(
        iaGradienteEncabezado,
        other.iaGradienteEncabezado,
      ),
      iaGradienteSimbolo: l(iaGradienteSimbolo, other.iaGradienteSimbolo),
      iaGradienteEnviar: l(iaGradienteEnviar, other.iaGradienteEnviar),
      iaBurbujaUsuario: l(iaBurbujaUsuario, other.iaBurbujaUsuario),
      sobreGradiente: c(sobreGradiente, other.sobreGradiente),
    );
  }
}
