import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =====================================================================
// DESIGN SYSTEM - ORELINHAS
// Paleta verde-floresta, tipografia arredondada (Nunito) e componentes
// suaves, baseados no protótipo visual do app.
// Uso exclusivamente visual — nenhuma lógica de negócio aqui.
// =====================================================================

/// Paleta de cores centralizada do Orelinhas.
class AppColors {
  AppColors._();

  // --- Primárias ---
  static const Color primary = Color(0xFF1F5C45);
  static const Color primaryDark = Color(0xFF143F30);
  static const Color primarySoft = Color(0xFFE6F0EA);

  /// Cor de destaque suave (fundos de ícones, chips claros).
  static const Color accent = Color(0xFFD5E8DD);

  // --- Superfícies ---
  static const Color scaffoldLight = Color(0xFFF6F7F3);
  static const Color surfaceLight = Colors.white;

  // --- Texto ---
  static const Color textPrimary = Color(0xFF1B2B24);
  static const Color textSecondary = Color(0xFF6E7D76);

  // --- Bordas ---
  static const Color border = Color(0xFFE3E8E4);

  // --- Status ---
  static const Color success = Color(0xFF2F8F5B);
  static const Color successSoft = Color(0xFFE3F3EA);
  static const Color error = Color(0xFFE5484D);
  static const Color errorSoft = Color(0xFFFDECEC);
  static const Color warning = Color(0xFFE8A13A);
}

/// Estilos de tipografia centralizados.
class AppTextStyles {
  AppTextStyles._();

  // --- Display (logo / títulos de destaque) ---
  static TextStyle display({Color? color}) => GoogleFonts.nunito(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    color: color ?? AppColors.primary,
    height: 1.1,
    letterSpacing: -0.5,
  );

  // --- Headings ---
  static TextStyle heading1({Color? color}) => GoogleFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: color ?? AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle heading2({Color? color}) => GoogleFonts.nunito(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle heading3({Color? color}) => GoogleFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.textPrimary,
  );

  // --- Body ---
  static TextStyle body({Color? color}) => GoogleFonts.nunito(
    fontSize: 14,
    color: color ?? AppColors.textPrimary,
    height: 1.45,
  );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.nunito(
    fontSize: 12,
    color: color ?? AppColors.textSecondary,
    height: 1.35,
  );

  // --- Labels ---
  static TextStyle label({Color? color}) => GoogleFonts.nunito(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: color ?? AppColors.textPrimary,
  );

  static TextStyle sectionHeader({Color? color}) => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: color ?? AppColors.textPrimary,
  );

  // --- Buttons ---
  static TextStyle button({Color? color}) => GoogleFonts.nunito(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: color ?? Colors.white,
  );
}

/// Tema global do app.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final inputRadius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.scaffoldLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primarySoft,
        onSecondary: AppColors.primary,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldLight,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          fontSize: 20,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.border.withAlpha(128)),
        ),
        prefixIconColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.nunito(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        hintStyle: GoogleFonts.nunito(
          fontSize: 14,
          color: const Color(0xFFA3AEA8),
        ),
        helperStyle: GoogleFonts.nunito(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        errorStyle: GoogleFonts.nunito(fontSize: 12, color: AppColors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(110),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surfaceLight,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.border, width: 1.2),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 24,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primary,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: GoogleFonts.nunito(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }
}
