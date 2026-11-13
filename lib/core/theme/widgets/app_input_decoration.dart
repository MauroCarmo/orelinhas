import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Decorações de entrada de texto padronizadas reutilizáveis em todas as telas.
/// O visual (bordas, cores, fontes) vem do `inputDecorationTheme` global.
class AppInputDecoration {
  AppInputDecoration._();

  /// Cria um InputDecoration padronizado para o sistema.
  /// Se [isSearch] for true, o campo fica em formato pílula e mais baixo.
  static InputDecoration defaultDecoration({
    required String labelText,
    String? hintText,
    String? helperText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isSearch = false,
  }) {
    return InputDecoration(
      labelText: labelText.isEmpty ? null : labelText,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSearch ? 12 : 15,
      ),
      border: isSearch ? _pill(AppColors.border) : null,
      enabledBorder: isSearch ? _pill(AppColors.border) : null,
      focusedBorder: isSearch ? _pill(AppColors.primary, width: 1.6) : null,
    );
  }

  static OutlineInputBorder _pill(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Rótulo acima de um campo de formulário, no estilo do protótipo.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text, style: AppTextStyles.label()),
    );
  }
}
