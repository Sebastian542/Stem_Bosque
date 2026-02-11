import 'token.dart';
import 'token_type.dart';

/// Analizador léxico que convierte código fuente en tokens
class Lexer {
  final String source;
  final List<Token> _tokens = [];
  
  int _start = 0;
  int _current = 0;
  int _line = 1;
  int _column = 1;

  // Palabras clave del lenguaje
  static const Map<String, TokenType> _keywords = {
    'PROGRAMA': TokenType.programa,
    'FIN': TokenType.fin,
    'SI': TokenType.si,
    'ENTONCES': TokenType.entonces,
    'REPETIR': TokenType.repetir,
    'VECES': TokenType.veces,
    'AVANZAR': TokenType.avanzar,
    'GIRAR': TokenType.girar,
  };

  Lexer(this.source);

  /// Tokeniza el código fuente completo
  List<Token> tokenize() {
    while (!_isAtEnd()) {
      _start = _current;
      _scanToken();
    }

    _addToken(TokenType.finArchivo);
    return _tokens;
  }

  void _scanToken() {
    final c = _advance();
    
    switch (c) {
      case ' ':
      case '\r':
      case '\t':
        _column++;
        break;
        
      case '\n':
        _line++;
        _column = 1;
        break;
        
      case '=':
        if (_match('=')) {
          _addToken(TokenType.igualIgual);
        } else {
          _addToken(TokenType.igual);
        }
        break;
        
      case '<':
        _addToken(TokenType.menorQue);
        break;
        
      case '>':
        _addToken(TokenType.mayorQue);
        break;
        
      case '[':
        _addToken(TokenType.corcheteAbre);
        break;
        
      case ']':
        _addToken(TokenType.corcheteCierra);
        break;
        
      case ':':
        _addToken(TokenType.dobleComa);
        break;
        
      case '"':
        _string();
        break;
        
      case '/':
        if (_match('*')) {
          _multiLineComment();
        } else if (_match('/')) {
          _singleLineComment();
        }
        break;
        
      default:
        if (_isDigit(c) || (c == '-' && _isDigit(_peek()))) {
          _number();
        } else if (_isAlpha(c)) {
          _identifier();
        } else {
          _addToken(TokenType.desconocido);
        }
    }
  }

  void _string() {
    while (_peek() != '"' && !_isAtEnd()) {
      if (_peek() == '\n') {
        _line++;
        _column = 1;
      }
      _advance();
    }

    if (_isAtEnd()) {
      throw Exception('Cadena sin cerrar en línea $_line');
    }

    _advance(); // Comilla de cierre
    
    final value = source.substring(_start + 1, _current - 1);
    _addToken(TokenType.cadena, value);
  }

  void _multiLineComment() {
    while (!_isAtEnd()) {
      if (_peek() == '*' && _peekNext() == '/') {
        _advance(); // *
        _advance(); // /
        break;
      }
      if (_peek() == '\n') {
        _line++;
        _column = 1;
      }
      _advance();
    }
    _addToken(TokenType.comentario);
  }

  void _singleLineComment() {
    while (_peek() != '\n' && !_isAtEnd()) {
      _advance();
    }
    _addToken(TokenType.comentario);
  }

  void _number() {
    bool isNegative = false;
    if (_peekPrevious() == '-') {
      isNegative = true;
    }
    
    while (_isDigit(_peek())) {
      _advance();
    }

    final value = int.parse(source.substring(_start, _current));
    _addToken(TokenType.numero, value);
  }

  void _identifier() {
    while (_isAlphaNumeric(_peek())) {
      _advance();
    }

    final text = source.substring(_start, _current);
    final type = _keywords[text.toUpperCase()] ?? TokenType.identificador;
    _addToken(type);
  }

  bool _match(String expected) {
    if (_isAtEnd()) return false;
    if (source[_current] != expected) return false;

    _current++;
    _column++;
    return true;
  }

  String _advance() {
    _column++;
    return source[_current++];
  }

  String _peek() {
    if (_isAtEnd()) return '\0';
    return source[_current];
  }

  String _peekNext() {
    if (_current + 1 >= source.length) return '\0';
    return source[_current + 1];
  }

  String _peekPrevious() {
    if (_current - 1 < 0) return '\0';
    return source[_current - 1];
  }

  bool _isAtEnd() => _current >= source.length;

  bool _isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;

  bool _isAlpha(String c) {
    return (c.compareTo('a') >= 0 && c.compareTo('z') <= 0) ||
           (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) ||
           c == '_';
  }

  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c);

  void _addToken(TokenType type, [dynamic literal]) {
    final text = source.substring(_start, _current);
    _tokens.add(Token(
      type: type,
      lexeme: text,
      literal: literal,
      line: _line,
      column: _column - text.length,
    ));
  }
}
