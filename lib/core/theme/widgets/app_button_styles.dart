import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

/// Estilos de botão padronizados reutilizáveis em todas as telas.
class AppButtonStyles {
  AppButtonStyles._();

  /// Botão primário preenchido (ação principal).
  static ButtonStyle primary({Color? backgroundColor, Color? foregroundColor}) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor ?? AppColors.accent,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  /// Botão de sucesso (ação positiva como "Ajudar / Contatar").
  static ButtonStyle success() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }

  /// Botão de perigo (ação destrutiva como "Excluir").
  static ButtonStyle danger() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.error,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }

  /// Botão contornado (ação secundária).
  static ButtonStyle outlined() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: AppColors.border),
      textStyle: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700),
    );
  }
}
