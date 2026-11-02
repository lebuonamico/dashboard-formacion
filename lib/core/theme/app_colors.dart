import 'package:flutter/material.dart';

/// Text (or icon) color and its background, for chips, badges and notices.
@immutable
class ColorPair {
  final Color text;
  final Color background;

  const ColorPair(this.text, this.background);

  static ColorPair lerp(ColorPair a, ColorPair b, double t) => ColorPair(
    Color.lerp(a.text, b.text, t)!,
    Color.lerp(a.background, b.background, t)!,
  );
}

/// App colors that Material's [ColorScheme] does not cover: traffic-light
/// states, course categories, seniority, side menu and the AI assistant.
/// Surface, text, border and brand colors come from the [ColorScheme] (see
/// `AppTheme`).
///
/// Together with `app_theme.dart`, the only place with literal colors.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Text between `onSurface` (titles) and `onSurfaceVariant` (secondary).
  final Color intermediateText;

  /// Lowest-hierarchy text: placeholders, disabled items, axes.
  final Color faintText;

  final ColorPair success;
  final ColorPair warning;
  final ColorPair danger;

  /// Chips without a status (for example, a category that is not required).
  final ColorPair neutral;

  final ColorPair business;
  final ColorPair softSkills;
  final ColorPair exploration;
  final ColorPair teaching;

  final ColorPair trainee;
  final ColorPair junior;
  final ColorPair semisenior;
  final ColorPair senior;
  final ColorPair manager;

  /// Track of donuts and progress bars.
  final Color chartTrack;

  /// Decorative accents for KPI icons that do not represent a status.
  final Color cyanAccent;
  final Color violetAccent;

  final Color sidebarBackground;
  final Color sidebarBorder;
  final Color sidebarHover;
  final Color sidebarActive;

  /// Violet accent of the AI assistant (focus, bullets, code).
  final ColorPair ai;
  final List<Color> aiHeaderGradient;
  final List<Color> aiSymbolGradient;
  final List<Color> aiSendGradient;
  final List<Color> aiUserBubble;

  /// Text and icons over the assistant gradients.
  final Color overGradient;

  const AppColors({
    required this.intermediateText,
    required this.faintText,
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
    required this.business,
    required this.softSkills,
    required this.exploration,
    required this.teaching,
    required this.trainee,
    required this.junior,
    required this.semisenior,
    required this.senior,
    required this.manager,
    required this.chartTrack,
    required this.cyanAccent,
    required this.violetAccent,
    required this.sidebarBackground,
    required this.sidebarBorder,
    required this.sidebarHover,
    required this.sidebarActive,
    required this.ai,
    required this.aiHeaderGradient,
    required this.aiSymbolGradient,
    required this.aiSendGradient,
    required this.aiUserBubble,
    required this.overGradient,
  });

  static const light = AppColors(
    intermediateText: Color(0xFF334155),
    faintText: Color(0xFF94A3B8),
    success: ColorPair(Color(0xFF15803D), Color(0xFFDCFCE7)),
    warning: ColorPair(Color(0xFFB45309), Color(0xFFFEF3C7)),
    // Red 700: the 600 on its pink background did not reach AA contrast.
    danger: ColorPair(Color(0xFFB91C1C), Color(0xFFFEE2E2)),
    neutral: ColorPair(Color(0xFF475569), Color(0xFFF1F5F9)),
    business: ColorPair(Color(0xFF1D4ED8), Color(0xFFEFF6FF)),
    softSkills: ColorPair(Color(0xFF7E22CE), Color(0xFFF3E8FF)),
    exploration: ColorPair(Color(0xFF047857), Color(0xFFECFDF5)),
    teaching: ColorPair(Color(0xFFC2410C), Color(0xFFFFF7ED)),
    trainee: ColorPair(Color(0xFF475569), Color(0xFFF1F5F9)),
    junior: ColorPair(Color(0xFF0369A1), Color(0xFFE0F2FE)),
    semisenior: ColorPair(Color(0xFF6D28D9), Color(0xFFEDE9FE)),
    senior: ColorPair(Color(0xFF0D53C3), Color(0xFFDBEAFE)),
    manager: ColorPair(Color(0xFF0F766E), Color(0xFFCCFBF1)),
    chartTrack: Color(0xFFE5ECFA),
    cyanAccent: Color(0xFF0E7490),
    violetAccent: Color(0xFF6941C6),
    sidebarBackground: Color(0xFFEAF3FE),
    sidebarBorder: Color(0xFFD2E3F8),
    sidebarHover: Color(0xFFD6E7FD),
    sidebarActive: Color(0xFFFFFFFF),
    ai: ColorPair(Color(0xFF6451D8), Color(0xFFF0F3FC)),
    aiHeaderGradient: [Color(0xFF122E62), Color(0xFF283574), Color(0xFF514197)],
    aiSymbolGradient: [Color(0xFF2463CC), Color(0xFF7755CC), Color(0xFF37B8CB)],
    aiSendGradient: [Color(0xFF3462CE), Color(0xFF7954D6)],
    aiUserBubble: [Color(0xFFEDF3FF), Color(0xFFEEEDFD)],
    overGradient: Color(0xFFFFFFFF),
  );

  /// In dark mode chip backgrounds are the text color at low opacity: the
  /// light-mode pastels glare on dark surfaces.
  static const dark = AppColors(
    intermediateText: Color(0xFFCBD5E1),
    faintText: Color(0xFF64748B),
    success: ColorPair(Color(0xFF4ADE80), Color(0x2622C55E)),
    warning: ColorPair(Color(0xFFFBBF24), Color(0x26F59E0B)),
    danger: ColorPair(Color(0xFFF87171), Color(0x26EF4444)),
    neutral: ColorPair(Color(0xFFCBD5E1), Color(0x2694A3B8)),
    business: ColorPair(Color(0xFF93C5FD), Color(0x263B82F6)),
    softSkills: ColorPair(Color(0xFFD8B4FE), Color(0x26A855F7)),
    exploration: ColorPair(Color(0xFF6EE7B7), Color(0x2610B981)),
    teaching: ColorPair(Color(0xFFFDBA74), Color(0x26F97316)),
    trainee: ColorPair(Color(0xFFCBD5E1), Color(0x2694A3B8)),
    junior: ColorPair(Color(0xFF7DD3FC), Color(0x260EA5E9)),
    semisenior: ColorPair(Color(0xFFC4B5FD), Color(0x268B5CF6)),
    senior: ColorPair(Color(0xFF93C5FD), Color(0x263B82F6)),
    manager: ColorPair(Color(0xFF5EEAD4), Color(0x2614B8A6)),
    chartTrack: Color(0xFF263248),
    cyanAccent: Color(0xFF22D3EE),
    violetAccent: Color(0xFFB39DFF),
    sidebarBackground: Color(0xFF0E1A30),
    sidebarBorder: Color(0xFF1E2D4A),
    sidebarHover: Color(0xFF182A4A),
    sidebarActive: Color(0xFF1F3A66),
    ai: ColorPair(Color(0xFFA99BFF), Color(0xFF1A2238)),
    aiHeaderGradient: [Color(0xFF122E62), Color(0xFF283574), Color(0xFF514197)],
    aiSymbolGradient: [Color(0xFF2463CC), Color(0xFF7755CC), Color(0xFF37B8CB)],
    aiSendGradient: [Color(0xFF3462CE), Color(0xFF7954D6)],
    aiUserBubble: [Color(0xFF1C2B4D), Color(0xFF29254F)],
    overGradient: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? intermediateText,
    Color? faintText,
    ColorPair? success,
    ColorPair? warning,
    ColorPair? danger,
    ColorPair? neutral,
    ColorPair? business,
    ColorPair? softSkills,
    ColorPair? exploration,
    ColorPair? teaching,
    ColorPair? trainee,
    ColorPair? junior,
    ColorPair? semisenior,
    ColorPair? senior,
    ColorPair? manager,
    Color? chartTrack,
    Color? cyanAccent,
    Color? violetAccent,
    Color? sidebarBackground,
    Color? sidebarBorder,
    Color? sidebarHover,
    Color? sidebarActive,
    ColorPair? ai,
    List<Color>? aiHeaderGradient,
    List<Color>? aiSymbolGradient,
    List<Color>? aiSendGradient,
    List<Color>? aiUserBubble,
    Color? overGradient,
  }) => AppColors(
    intermediateText: intermediateText ?? this.intermediateText,
    faintText: faintText ?? this.faintText,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    neutral: neutral ?? this.neutral,
    business: business ?? this.business,
    softSkills: softSkills ?? this.softSkills,
    exploration: exploration ?? this.exploration,
    teaching: teaching ?? this.teaching,
    trainee: trainee ?? this.trainee,
    junior: junior ?? this.junior,
    semisenior: semisenior ?? this.semisenior,
    senior: senior ?? this.senior,
    manager: manager ?? this.manager,
    chartTrack: chartTrack ?? this.chartTrack,
    cyanAccent: cyanAccent ?? this.cyanAccent,
    violetAccent: violetAccent ?? this.violetAccent,
    sidebarBackground: sidebarBackground ?? this.sidebarBackground,
    sidebarBorder: sidebarBorder ?? this.sidebarBorder,
    sidebarHover: sidebarHover ?? this.sidebarHover,
    sidebarActive: sidebarActive ?? this.sidebarActive,
    ai: ai ?? this.ai,
    aiHeaderGradient: aiHeaderGradient ?? this.aiHeaderGradient,
    aiSymbolGradient: aiSymbolGradient ?? this.aiSymbolGradient,
    aiSendGradient: aiSendGradient ?? this.aiSendGradient,
    aiUserBubble: aiUserBubble ?? this.aiUserBubble,
    overGradient: overGradient ?? this.overGradient,
  );

  /// Interpolates every color, so switching light/dark animates instead of
  /// jumping.
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    ColorPair p(ColorPair a, ColorPair b) => ColorPair.lerp(a, b, t);
    List<Color> l(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) c(a[i], b[i]),
    ];

    return AppColors(
      intermediateText: c(intermediateText, other.intermediateText),
      faintText: c(faintText, other.faintText),
      success: p(success, other.success),
      warning: p(warning, other.warning),
      danger: p(danger, other.danger),
      neutral: p(neutral, other.neutral),
      business: p(business, other.business),
      softSkills: p(softSkills, other.softSkills),
      exploration: p(exploration, other.exploration),
      teaching: p(teaching, other.teaching),
      trainee: p(trainee, other.trainee),
      junior: p(junior, other.junior),
      semisenior: p(semisenior, other.semisenior),
      senior: p(senior, other.senior),
      manager: p(manager, other.manager),
      chartTrack: c(chartTrack, other.chartTrack),
      cyanAccent: c(cyanAccent, other.cyanAccent),
      violetAccent: c(violetAccent, other.violetAccent),
      sidebarBackground: c(sidebarBackground, other.sidebarBackground),
      sidebarBorder: c(sidebarBorder, other.sidebarBorder),
      sidebarHover: c(sidebarHover, other.sidebarHover),
      sidebarActive: c(sidebarActive, other.sidebarActive),
      ai: p(ai, other.ai),
      aiHeaderGradient: l(aiHeaderGradient, other.aiHeaderGradient),
      aiSymbolGradient: l(aiSymbolGradient, other.aiSymbolGradient),
      aiSendGradient: l(aiSendGradient, other.aiSendGradient),
      aiUserBubble: l(aiUserBubble, other.aiUserBubble),
      overGradient: c(overGradient, other.overGradient),
    );
  }
}
