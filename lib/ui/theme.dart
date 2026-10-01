import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Alerto design system.
///
/// Typography: Quicksand (rounded geometric — the app's voice everywhere).
/// Surfaces: iOS-style glass is reserved for *layered chrome only* — the top
/// app bar, the bottom navigation, and incoming alert banners — where content
/// genuinely scrolls underneath. Cards stay solid for scanability (Operate
/// mode: data-first surfaces keep flat, readable containers).
abstract final class AppColors {
  // Shared accents
  static const gold = Color(0xFFF59E0B);
  static const goldSoft = Color(0xFFFBBF24);
  static const purple = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);

  // Dark palette
  static const bgDark = Color(0xFF0F172A);
  static const cardDark = Color(0xFF222735);
  static const cardMutedDark = Color(0xFF272F42);
  static const textDark = Color(0xFFF8FAFC);
  static const textDimDark = Color(0xFFA6B0C3); // lifted for 4.5:1 on cards
  static const borderDark = Color(0xFF334155);

  // Light palette
  static const bgLight = Color(0xFFF6F7FB);
  static const cardLight = Colors.white;
  static const cardMutedLight = Color(0xFFEEF1F7);
  static const textLight = Color(0xFF141B2D);
  static const textDimLight = Color(0xFF5B6577); // 4.5:1+ on white
  static const borderLight = Color(0xFFDDE3ED);
}

abstract final class AppTheme {
  // Legacy static aliases (dark palette) used by screens written before
  // theme-mode support. Accents (gold/purple/green/red) are mode-independent;
  // surfaces/text here are the dark variants kept for stability.
  static const bg = AppColors.bgDark;
  static const card = AppColors.cardDark;
  static const cardMuted = AppColors.cardMutedDark;
  static const textPrimary = AppColors.textDark;
  static const textSecondary = AppColors.textDimDark;
  static const border = AppColors.borderDark;

  static ThemeData dark() => _theme(_Scheme.dark);
  static ThemeData light() => _theme(_Scheme.light);

  static ThemeData _theme(_Scheme c) {
    final base = c.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    final text = _textTheme(c);

    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        onPrimary: c.isDark ? const Color(0xFF1A1204) : Colors.white,
        secondary: AppColors.purple,
        onSecondary: Colors.white,
        surface: c.card,
        onSurface: c.text,
        surfaceContainerHighest: c.cardMuted,
        error: AppColors.red,
        outline: c.border,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: c.glassBar, // translucent -> BackdropFilter in shell
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.text),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: c.isDark ? 0 : 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.cardMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        labelStyle: TextStyle(color: c.textDim),
        hintStyle: TextStyle(color: c.textDim),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: c.isDark ? const Color(0xFF1A1204) : Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.cardMuted,
        selectedColor: AppColors.gold.withOpacity(0.18),
        labelStyle: TextStyle(color: c.text),
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.cardMuted,
        contentTextStyle: TextStyle(color: c.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.glassBar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.gold.withOpacity(0.16),
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.green
              : c.cardMuted,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
      ),
    );
  }

  static TextTheme _textTheme(_Scheme c) {
    // Quicksand everywhere; weights carry hierarchy.
    TextStyle s(double size, FontWeight w,
            {double? height, double? spacing, Color? color}) =>
        GoogleFonts.quicksand(
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: spacing,
          color: color ?? c.text,
        );

    return TextTheme(
      displaySmall: s(36, FontWeight.w700, spacing: -0.8),
      headlineMedium: s(26, FontWeight.w700, spacing: -0.5),
      titleLarge: s(19, FontWeight.w700, spacing: -0.2),
      titleMedium: s(16, FontWeight.w700),
      bodyLarge: s(15, FontWeight.w500, height: 1.45),
      bodyMedium: s(14, FontWeight.w500, height: 1.4),
      bodySmall: s(12.5, FontWeight.w500, color: c.textDim, height: 1.35),
      labelLarge: s(15, FontWeight.w700),
      labelMedium: s(13, FontWeight.w700),
      labelSmall: s(11, FontWeight.w700, color: c.textDim),
    );
  }
}

class _Scheme {
  const _Scheme({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.cardMuted,
    required this.text,
    required this.textDim,
    required this.border,
    required this.glassBar,
  });

  final bool isDark;
  final Color bg;
  final Color card;
  final Color cardMuted;
  final Color text;
  final Color textDim;
  final Color border;
  final Color glassBar;

  static const dark = _Scheme(
    isDark: true,
    bg: AppColors.bgDark,
    card: AppColors.cardDark,
    cardMuted: AppColors.cardMutedDark,
    text: AppColors.textDark,
    textDim: AppColors.textDimDark,
    border: AppColors.borderDark,
    glassBar: Color(0xCC101A30), // ~80% opacity navy for glass bars
  );

  static const light = _Scheme(
    isDark: false,
    bg: AppColors.bgLight,
    card: AppColors.cardLight,
    cardMuted: AppColors.cardMutedLight,
    text: AppColors.textLight,
    textDim: AppColors.textDimLight,
    border: AppColors.borderLight,
    glassBar: Color(0xD9FFFFFF), // ~85% opacity white for glass bars
  );
}

/// Convenience accessors used across screens (theme-mode aware).
extension AppSchemeX on ThemeData {
  bool get isDark => brightness == Brightness.dark;
  Color get textDim => isDark ? AppColors.textDimDark : AppColors.textDimLight;
  Color get good => AppColors.green;
  Color get bad => AppColors.red;
}
