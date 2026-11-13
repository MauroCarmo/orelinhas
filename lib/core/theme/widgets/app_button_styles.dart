import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

/// Estilos de botão padronizados reutilizáveis em todas as telas.
class AppButtonStyles {
  AppButtonStyles._();

  static TextStyle get _text =>
      GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800);

  /// Botão primário preenchido (ação principal).
  static ButtonStyle primary({Color? backgroundColor, Color? foregroundColor}) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor ?? Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
      shape: const StadiumBorder(),
      textStyle: _text,
    );
  }

  /// Botão de sucesso (ação positiva como "Ajudar / Contatar").
  static ButtonStyle success() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
      shape: const StadiumBorder(),
      textStyle: _text,
    );
  }

  /// Botão de perigo (ação destrutiva como "Excluir").
  static ButtonStyle danger() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.error,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
      shape: const StadiumBorder(),
      textStyle: _text,
    );
  }

  /// Botão contornado (ação secundária).
  static ButtonStyle outlined({Color? foregroundColor}) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor ?? AppColors.primary,
      backgroundColor: AppColors.surfaceLight,
      elevation: 0,
      minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
      shape: const StadiumBorder(),
      side: BorderSide(
        color: foregroundColor?.withAlpha(90) ?? AppColors.border,
        width: 1.2,
      ),
      textStyle: _text,
    );
  }
}
