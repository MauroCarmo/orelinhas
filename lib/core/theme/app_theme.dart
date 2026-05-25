import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =====================================================================
// DESIGN SYSTEM - ORELINHAS
// Paleta, tipografia e tema baseados no protótipo de referência.
// Uso exclusivamente visual — nenhuma lógica de negócio aqui.
// =====================================================================

/// Paleta de cores centralizada do Orelinhas.
class AppColors {
  AppColors._();

  // --- Primárias ---
  static const Color primary = Color(0xFF132A32);
  static const Color accent = Color(0xFFC6E21E);

  // --- Superfícies ---
  static const Color scaffoldLight = Color(0xFFF4F7F6);
  static const Color surfaceLight = Colors.white;

  // --- Texto ---
  static const Color textPrimary = Color(0xFF213135);
  static const Color textSecondary = Color(0xFF94A3B8);

  // --- Bordas ---
  static const Color border = Color(0xFFE2E8F0);

  // --- Status ---
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
}

/// Estilos de tipografia centralizados.
class AppTextStyles {
  AppTextStyles._();

  // --- Headings (Poppins) ---
  static TextStyle heading1({Color? color}) => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle heading2({Color? color}) => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle heading3({Color? color}) => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
      );

  // --- Body (Lato) ---
  static TextStyle body({Color? color}) => GoogleFonts.lato(
        fontSize: 13,
        color: color ?? AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.lato(
        fontSize: 11,
        color: color ?? AppColors.textSecondary,
        height: 1.3,
      );

  // --- Labels ---
  static TextStyle label({Color? color}) => GoogleFonts.lato(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle sectionHeader({Color? color}) => GoogleFonts.lato(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textSecondary,
        letterSpacing: 0.5,
      );

  // --- Buttons ---
  static TextStyle button({Color? color}) => GoogleFonts.lato(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.accent,
      );
}

/// Tema global do app.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.scaffoldLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.latoTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: 18,
        ),
        shape: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: AppColors.border.withAlpha(128)),
        ),
        labelStyle: GoogleFonts.lato(fontSize: 13, color: AppColors.textSecondary),
        hintStyle: GoogleFonts.lato(fontSize: 13, color: AppColors.textSecondary),
        helperStyle: GoogleFonts.lato(fontSize: 11, color: AppColors.textSecondary),
        errorStyle: GoogleFonts.lato(fontSize: 11, color: AppColors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.accent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.border),
          textStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 24,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.accent,
        labelStyle: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primary,
        elevation: 4,
      ),
    );
  }
}
