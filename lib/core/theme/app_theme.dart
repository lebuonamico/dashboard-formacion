import 'package:app_finnegans/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

export 'package:app_finnegans/core/theme/app_colors.dart';

/// Light and dark themes. Screens do not write colors: they read
/// `context.colorScheme` (surfaces, text, borders, brand) and `context.colors`
/// ([AppColors]: states, categories, seniority, side menu, assistant). Shared
/// component styles (inputs, menus, dividers, buttons) also live here.
abstract final class AppTheme {
  static const _brand = Color(0xFF0D53C3);

  static ThemeData light() => _build(_lightScheme, AppColors.light);

  static ThemeData dark() => _build(_darkScheme, AppColors.dark);

  // Tailwind slate over the Finnegans blue: the palette the app already used,
  // now named by role.
  static final _lightScheme =
      ColorScheme.fromSeed(
        seedColor: _brand,
        brightness: Brightness.light,
      ).copyWith(
        primary: _brand,
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: const Color(0xFFEFF6FF),
        onPrimaryContainer: const Color(0xFF1D4ED8),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF0F172A),
        onSurfaceVariant: const Color(0xFF64748B),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF8FAFC),
        surfaceContainer: const Color(0xFFF1F5F9),
        surfaceContainerHigh: const Color(0xFFE2E8F0),
        surfaceContainerHighest: const Color(0xFFCBD5E1),
        outline: const Color(0xFFCBD5E1),
        outlineVariant: const Color(0xFFE2E8F0),
        error: const Color(0xFFDC2626),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFFEE2E2),
        onErrorContainer: const Color(0xFF991B1B),
        shadow: const Color(0xFF0F172A),
        surfaceTint: const Color(0x00000000),
      );

  // Deep slate backgrounds (not pure black) and a lighter brand blue, so text
  // and links meet AA contrast on dark surfaces.
  static final _darkScheme =
      ColorScheme.fromSeed(
        seedColor: _brand,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF60A5FA),
        onPrimary: const Color(0xFF0B1220),
        primaryContainer: const Color(0xFF172B52),
        onPrimaryContainer: const Color(0xFFBFDBFE),
        surface: const Color(0xFF131C2E),
        onSurface: const Color(0xFFE2E8F0),
        onSurfaceVariant: const Color(0xFF94A3B8),
        surfaceContainerLowest: const Color(0xFF0B1220),
        surfaceContainerLow: const Color(0xFF0B1220),
        surfaceContainer: const Color(0xFF1A2438),
        surfaceContainerHigh: const Color(0xFF263248),
        surfaceContainerHighest: const Color(0xFF334155),
        outline: const Color(0xFF3A4A63),
        outlineVariant: const Color(0xFF243149),
        error: const Color(0xFFF87171),
        onError: const Color(0xFF0B1220),
        errorContainer: const Color(0xFF3B1219),
        onErrorContainer: const Color(0xFFFECACA),
        shadow: const Color(0xFF000000),
        surfaceTint: const Color(0x00000000),
      );

  static const _textTheme = TextTheme(
    displaySmall: TextStyle(fontSize: 28),
    titleMedium: TextStyle(fontSize: 18),
    bodySmall: TextStyle(fontSize: 13),
    labelSmall: TextStyle(fontSize: 10),
  );

  static ThemeData _build(ColorScheme cs, AppColors colors) {
    final borderInput = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: cs.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      textTheme: _textTheme.apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      colorScheme: cs,
      extensions: [colors],
      scaffoldBackgroundColor: cs.surfaceContainerLow,
      canvasColor: cs.surface,
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
      // Paginated tables (employees, courses, CRM, LMS): small grey headers, no
      // background, and rows across the whole panel.
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(Color(0x00000000)),
        headingTextStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
        horizontalMargin: 0,
        dividerThickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        hintStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        prefixIconColor: cs.onSurfaceVariant,
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 10,
        ),
        border: borderInput,
        enabledBorder: borderInput,
        disabledBorder: borderInput,
        focusedBorder: borderInput.copyWith(
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          disabledForegroundColor: colors.faintText,
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: colors.chartTrack,
      ),
    );
  }
}

extension ThemeContext on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;

  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  /// Standard panel (cards, tables, filter bars): surface, soft border and
  /// radius 8, with an optional shadow.
  BoxDecoration panel({bool shadow = false, double radius = 8}) {
    final cs = colorScheme;
    return BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cs.outlineVariant),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ]
          : null,
    );
  }
}
