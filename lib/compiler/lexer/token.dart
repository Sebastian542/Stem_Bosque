import 'token_type.dart';

/// Representa un token individual en el código fuente
class Token {
  final TokenType type;
  final String lexeme;
  final dynamic literal;
  final int line;
  final int column;

  Token({
    required this.type,
    required this.lexeme,
    this.literal,
    required this.line,
    required this.column,
  });

  @override
  String toString() {
    return 'Token(${type.displayName}, "$lexeme", line: $line, col: $column)';
  }

  bool get esSignificativo {
    return type != TokenType.espacioBlanco && 
           type != TokenType.comentario;
  }

  Token copyWith({
    TokenType? type,
    String? lexeme,
    dynamic literal,
    int? line,
    int? column,
  }) {
    return Token(
      type: type ?? this.type,
      lexeme: lexeme ?? this.lexeme,
      literal: literal ?? this.literal,
      line: line ?? this.line,
      column: column ?? this.column,
    );
  }
}
