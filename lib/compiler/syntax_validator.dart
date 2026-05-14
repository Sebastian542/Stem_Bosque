import 'lexer/lexer.dart';
import 'parser/parser.dart';

class ValidationResult {
  final bool isValid;
  final int? errorLine;
  final String? errorMessage;

  const ValidationResult.valid()
      : isValid = true, errorLine = null, errorMessage = null;

  const ValidationResult.error(this.errorLine, this.errorMessage)
      : isValid = false;
}

class SyntaxValidator {
  final List<String> customCommands;

  SyntaxValidator({this.customCommands = const []});

  ValidationResult validate(String source, {List<String> comandosPersonalizados = const []}) {
    if (source.trim().isEmpty) return const ValidationResult.valid();
    try {
      final tokens = AnalizadorLexico(source, comandosPersonalizados: comandosPersonalizados).tokenizar();
      Parser(tokens).parsePrograma();
      return const ValidationResult.valid();
    } catch (e) {
      final msg  = e.toString();
      final line = _extractLine(msg);
      return ValidationResult.error(line, msg);
    }
  }

  int? _extractLine(String message) {
    final match = RegExp(r'línea\s+(\d+)').firstMatch(message);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }
}