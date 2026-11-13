import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette WGF CONNECT: nero profondo, viola elettrico, viola scuro, bianco, antracite.
abstract final class WgfColors {
  static const black = Color(0xFF07060B);
  static const anthracite = Color(0xFF1C1B22);
  static const surface = Color(0xFF121118);
  static const electricViolet = Color(0xFF8B2CFF);
  static const darkViolet = Color(0xFF3A0F6E);
  static const white = Color(0xFFF7F5FF);
  static const muted = Color(0xFF9C98AD);
  static const danger = Color(0xFFFF4D6A);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [electricViolet, darkViolet],
  );
}

abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = const ColorScheme.dark(
      primary: WgfColors.electricViolet,
      onPrimary: WgfColors.white,
      secondary: WgfColors.darkViolet,
      surface: WgfColors.surface,
      onSurface: WgfColors.white,
      error: WgfColors.danger,
    );
    final text = GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: WgfColors.white,
      displayColor: WgfColors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: WgfColors.black,
      textTheme: text.copyWith(
        headlineLarge: GoogleFonts.orbitron(
          textStyle: text.headlineLarge,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WgfColors.anthracite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: WgfColors.electricViolet, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: WgfColors.surface.withValues(alpha: 0.96),
        indicatorColor: WgfColors.darkViolet,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: WgfColors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: WgfColors.electricViolet,
        foregroundColor: WgfColors.white,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WgfColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WgfColors.anthracite,
        contentTextStyle: TextStyle(color: WgfColors.white),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: WgfColors.anthracite,
        selectedColor: WgfColors.darkViolet,
        side: BorderSide.none,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WgfColors.white,
          side: const BorderSide(color: WgfColors.electricViolet),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(0, 48),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
      ),
    );
  }
}
