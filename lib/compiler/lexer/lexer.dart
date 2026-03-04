import '../models/token.dart';

class ErrorLexico implements Exception {
  final String mensaje;
  ErrorLexico(this.mensaje);
  @override
  String toString() => mensaje;
}

class AnalizadorLexico {
  final String fuente;
  int _pos = 0;
  int _linea = 1;

  static const Map<String, TipoToken> _palabrasClave = {
    'PROGRAMA': TipoToken.PROGRAMA,
    'FIN':      TipoToken.FIN,
    'GIRAR':    TipoToken.GIRAR,
    'AVANZAR':  TipoToken.AVANZAR,
    'SI':       TipoToken.SI,
    'ENTONCES': TipoToken.ENTONCES,
    'REPETIR':  TipoToken.REPETIR,
    'VECES':    TipoToken.VECES,
    'AND':      TipoToken.AND,
    'OR':       TipoToken.OR,
    'NOT':      TipoToken.NOT,
    'SEN':      TipoToken.SEN,
    'COS':      TipoToken.COS,
    'TANG':     TipoToken.TANG,
  };

  AnalizadorLexico(this.fuente);

  List<Token> tokenizar() {
    final tokens = <Token>[];

    while (_pos < fuente.length) {
      _saltarEspacios();
      if (_pos >= fuente.length) break;

      final ch = fuente[_pos];

      if (ch == '\n') { _linea++; _pos++; continue; }

      // Comentarios
      if (ch == '/' && _pos + 1 < fuente.length) {
        if (fuente[_pos + 1] == '/') {
          while (_pos < fuente.length && fuente[_pos] != '\n') {
            _pos++;
          }
          continue;
        }
        if (fuente[_pos + 1] == '*') {
          _pos += 2;
          while (_pos < fuente.length) {
            if (fuente[_pos] == '\n') { _linea++; _pos++; }
            else if (fuente[_pos] == '*' && _pos + 1 < fuente.length && fuente[_pos + 1] == '/') {
              _pos += 2; break;
            } else { _pos++; }
          }
          continue;
        }
      }

      if (ch == '"')    { tokens.add(_leerTexto()); continue; }
      if (_esDigito(ch)) { tokens.add(_leerNumero()); continue; }
      if (_esLetra(ch))  { tokens.add(_leerPalabra()); continue; }

      switch (ch) {
        case '=':
          if (_pos + 1 < fuente.length && fuente[_pos + 1] == '=') {
            tokens.add(Token(TipoToken.IGUAL, '==', _linea)); _pos += 2;
          } else {
            tokens.add(Token(TipoToken.ASIGNACION, '=', _linea)); _pos++;
          }
          break;
        case '>': tokens.add(Token(TipoToken.MAYOR,    '>',  _linea)); _pos++; break;
        case '<': tokens.add(Token(TipoToken.MENOR,    '<',  _linea)); _pos++; break;
        case '+': tokens.add(Token(TipoToken.SUMA,     '+',  _linea)); _pos++; break;
        case '-': tokens.add(Token(TipoToken.RESTA,    '-',  _linea)); _pos++; break;
        case '*': tokens.add(Token(TipoToken.MULT,     '*',  _linea)); _pos++; break;
        case '/': tokens.add(Token(TipoToken.DIV,      '/',  _linea)); _pos++; break;
        case '%': tokens.add(Token(TipoToken.MODULO,   '%',  _linea)); _pos++; break;
        case '^': tokens.add(Token(TipoToken.POTENCIA, '^',  _linea)); _pos++; break;
        case ':': tokens.add(Token(TipoToken.DOS_PUNTOS,    ':', _linea)); _pos++; break;
        case '[': tokens.add(Token(TipoToken.CORCHETE_IZQ,  '[', _linea)); _pos++; break;
        case ']': tokens.add(Token(TipoToken.CORCHETE_DER,  ']', _linea)); _pos++; break;
        case '(': tokens.add(Token(TipoToken.PAREN_IZQ,     '(', _linea)); _pos++; break;
        case ')': tokens.add(Token(TipoToken.PAREN_DER,     ')', _linea)); _pos++; break;
        default:
          throw ErrorLexico(
              '😕 ¡Ups! En la línea $_linea hay un símbolo que no entiendo: "$ch"\n'
                  '💡 Revisa que no hayas escrito un símbolo raro o un espacio de más.'
          );
      }
    }

    tokens.add(Token(TipoToken.FIN_ARCHIVO, '', _linea));
    return tokens;
  }

  void _saltarEspacios() {
    while (_pos < fuente.length &&
        fuente[_pos] != '\n' &&
        (fuente[_pos] == ' ' || fuente[_pos] == '\t' || fuente[_pos] == '\r')) {
      _pos++;
    }
  }

  Token _leerTexto() {
    _pos++;
    final sb = StringBuffer();
    while (_pos < fuente.length && fuente[_pos] != '"') {
      if (fuente[_pos] == '\n') _linea++;
      sb.write(fuente[_pos++]);
    }
    if (_pos >= fuente.length) {
      throw ErrorLexico(
          '😕 En la línea $_linea abriste unas comillas " pero nunca las cerraste.\n'
              '💡 Asegúrate de que el nombre del programa esté entre comillas: "Mi programa"'
      );
    }
    _pos++;
    return Token(TipoToken.TEXTO, sb.toString(), _linea);
  }

  Token _leerNumero() {
    final inicio = _pos;
    while (_pos < fuente.length && _esDigito(fuente[_pos])) {
      _pos++;
    }
    // Parte decimal
    if (_pos < fuente.length && fuente[_pos] == '.' &&
        _pos + 1 < fuente.length && _esDigito(fuente[_pos + 1])) {
      _pos++;
      while (_pos < fuente.length && _esDigito(fuente[_pos])) {
        _pos++;
      }
    }
    return Token(TipoToken.NUMERO, fuente.substring(inicio, _pos), _linea);
  }

  Token _leerPalabra() {
    final inicio = _pos;
    while (_pos < fuente.length &&
        (_esLetra(fuente[_pos]) || _esDigito(fuente[_pos]) || fuente[_pos] == '_')) {
      _pos++;
    }
    final palabra = fuente.substring(inicio, _pos);
    final enMayusculas = palabra.toUpperCase();
    if (_palabrasClave.containsKey(enMayusculas) && !_palabrasClave.containsKey(palabra)) {
      return Token(_palabrasClave[enMayusculas]!, enMayusculas, _linea);
    }
    final tipo = _palabrasClave[palabra] ?? TipoToken.IDENTIFICADOR;
    return Token(tipo, palabra, _linea);
  }

  bool _esDigito(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _esLetra(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || c == '_';
  }
}
