import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

/// Decorações de entrada de texto padronizadas reutilizáveis em todas as telas.
class AppInputDecoration {
  AppInputDecoration._();

  /// Cria um InputDecoration padronizado para o sistema.
  /// Se [isSearch] for true, os padding verticais são menores.
  static InputDecoration defaultDecoration({
    required String labelText,
    String? hintText,
    String? helperText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isSearch = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isSearch ? 10 : 14,
      ),
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
      labelStyle: GoogleFonts.lato(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      hintStyle: GoogleFonts.lato(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      helperStyle: GoogleFonts.lato(
        fontSize: 11,
        color: AppColors.textSecondary,
      ),
      errorStyle: GoogleFonts.lato(
        fontSize: 11,
        color: AppColors.error,
      ),
    );
  }
}
