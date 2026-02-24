import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SihhaPalette {
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDeep = Color(0xFF0F766E);
  static const Color secondary = Color(0xFF0284C7);
  static const Color accent = Color(0xFF16A34A);
  static const Color surface = Color(0xFFF8FBFD);
  static const Color surfaceSoft = Color(0xFFEFF6FB);
  static const Color danger = Color(0xFFE53935);
  static const Color text = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF5E6B7B);
  static const Color night = Color(0xFF040608);
  static const Color nightSurface = Color(0xFF0C1118);
  static const Color nightSoft = Color(0xFF141C27);
  static const Color nightCard = Color(0xFF111A25);
  static const Color textOnDark = Color(0xFFE6EDF5);
  static const Color textMutedOnDark = Color(0xFF94A3B8);

  static const List<Color> pageGradient = [
    Color(0xFFE7FAF6),
    Color(0xFFF3FAFF),
    Color(0xFFF8FCFF),
  ];

  static const List<Color> pageGradientDark = [
    Color(0xFF040608),
    Color(0xFF0A1118),
    Color(0xFF0D1620),
  ];
}

class SihhaTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SihhaPalette.primary,
        primary: SihhaPalette.primary,
        secondary: SihhaPalette.secondary,
        surface: Colors.white,
        error: SihhaPalette.danger,
      ),
    );

    final textTheme = GoogleFonts.tajawalTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.tajawal(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: SihhaPalette.text,
      ),
      titleLarge: GoogleFonts.tajawal(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: SihhaPalette.text,
      ),
      titleMedium: GoogleFonts.tajawal(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: SihhaPalette.text,
      ),
      bodyMedium: GoogleFonts.tajawal(
        fontSize: 15,
        color: SihhaPalette.textMuted,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: SihhaPalette.surface,
      primaryColor: SihhaPalette.primary,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: SihhaPalette.text,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        indicatorColor: SihhaPalette.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.tajawal(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? SihhaPalette.primaryDeep : SihhaPalette.textMuted,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.96),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: GoogleFonts.tajawal(
          color: SihhaPalette.textMuted.withValues(alpha: 0.9),
          fontSize: 14.5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: SihhaPalette.secondary.withValues(alpha: 0.20),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: SihhaPalette.secondary.withValues(alpha: 0.16),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SihhaPalette.primary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData dark() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: SihhaPalette.primary,
      brightness: Brightness.dark,
    );
    final scheme = baseScheme.copyWith(
      primary: const Color(0xFF14B8A6),
      secondary: const Color(0xFF38BDF8),
      surface: SihhaPalette.nightSurface,
      onSurface: SihhaPalette.textOnDark,
      surfaceContainerHighest: SihhaPalette.nightSoft,
      error: SihhaPalette.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
    );

    final textTheme = GoogleFonts.tajawalTextTheme(base.textTheme).copyWith(
      headlineSmall: GoogleFonts.tajawal(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: SihhaPalette.textOnDark,
      ),
      titleLarge: GoogleFonts.tajawal(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: SihhaPalette.textOnDark,
      ),
      titleMedium: GoogleFonts.tajawal(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: SihhaPalette.textOnDark,
      ),
      bodyMedium: GoogleFonts.tajawal(
        fontSize: 15,
        color: SihhaPalette.textMutedOnDark,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: SihhaPalette.night,
      canvasColor: SihhaPalette.night,
      primaryColor: const Color(0xFF14B8A6),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: SihhaPalette.textOnDark,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B121A).withValues(alpha: 0.98),
        indicatorColor: const Color(0xFF14B8A6).withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.tajawal(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? const Color(0xFF7DEBDE)
                : SihhaPalette.textMutedOnDark,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111925),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: GoogleFonts.tajawal(
          color: SihhaPalette.textMutedOnDark.withValues(alpha: 0.92),
          fontSize: 14.5,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A3444)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A3444)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: SihhaPalette.nightCard.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF141D29),
        contentTextStyle: GoogleFonts.tajawal(color: SihhaPalette.textOnDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

BoxDecoration sihhaPageBackground({
  BuildContext? context,
  bool withBorder = false,
}) {
  final isDark =
      context != null && Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: isDark
          ? SihhaPalette.pageGradientDark
          : SihhaPalette.pageGradient,
    ),
    border: withBorder
        ? Border.all(
            color: isDark
                ? const Color(0xFF2A3444).withValues(alpha: 0.55)
                : SihhaPalette.secondary.withValues(alpha: 0.08),
          )
        : null,
  );
}

BoxDecoration sihhaGlassCardDecoration({BuildContext? context}) {
  final isDark =
      context != null && Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? SihhaPalette.nightCard.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.88),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: isDark
          ? const Color(0xFF2A3444).withValues(alpha: 0.80)
          : Colors.white.withValues(alpha: 0.75),
    ),
    boxShadow: [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.36)
            : SihhaPalette.secondary.withValues(alpha: 0.10),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
