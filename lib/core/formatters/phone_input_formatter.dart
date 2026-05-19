import 'package:flutter/services.dart';

/// Formatador de entrada de texto com máscara dinâmica para telefones brasileiros:
/// - Fixo (8 dígitos): (99) 9999-9999
/// - Celular (9 dígitos): (99) 99999-9999
class PhoneInputFormatter extends TextInputFormatter {
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
    final truncated = digits.length > 11 ? digits.substring(0, 11) : digits;

    final StringBuffer buffer = StringBuffer();

    if (truncated.isNotEmpty) {
      buffer.write('(');
      if (truncated.length <= 2) {
        buffer.write(truncated);
      } else {
        buffer.write('${truncated.substring(0, 2)}) ');
        
        if (truncated.length <= 6) {
          buffer.write(truncated.substring(2));
        } else if (truncated.length <= 10) {
          // Formato Fixo: (XX) XXXX-XXXX
          buffer.write('${truncated.substring(2, 6)}-${truncated.substring(6)}');
        } else {
          // Formato Celular: (XX) XXXXX-XXXX
          buffer.write('${truncated.substring(2, 7)}-${truncated.substring(7)}');
        }
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
