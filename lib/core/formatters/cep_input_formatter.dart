import 'package:flutter/services.dart';

/// Formatador de entrada de texto com máscara para CEP brasileiro:
/// - Máscara padrão: 99999-999
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Se estiver apagando texto, permite que o fluxo de deleção siga normalmente.
    if (oldValue.text.length > text.length) {
      return newValue;
    }

    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    final truncated = digits.length > 8 ? digits.substring(0, 8) : digits;

    final StringBuffer buffer = StringBuffer();

    if (truncated.isNotEmpty) {
      if (truncated.length <= 5) {
        buffer.write(truncated);
      } else {
        buffer.write('${truncated.substring(0, 5)}-${truncated.substring(5)}');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
