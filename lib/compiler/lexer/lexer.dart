import '../models/token.dart';

class ErrorLexico implements Exception {
  final String mensaje;
  ErrorLexico(this.mensaje);
  @override
  String toString() => '❌ Error Léxico: $mensaje';
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
  };

  AnalizadorLexico(this.fuente);

  List<Token> tokenizar() {
    final tokens = <Token>[];

    while (_pos < fuente.length) {
      _saltarEspacios();
      if (_pos >= fuente.length) break;

      final ch = fuente[_pos];

      // Salto de línea
      if (ch == '\n') {
        _linea++;
        _pos++;
        continue;
      }

      // ── Comentarios ────────────────────────────────────────
      if (ch == '/' && _pos + 1 < fuente.length) {
        // Comentario de línea: // ...
        if (fuente[_pos + 1] == '/') {
          while (_pos < fuente.length && fuente[_pos] != '\n') _pos++;
          continue;
        }
        // Comentario de bloque: /* ... */
        if (fuente[_pos + 1] == '*') {
          _pos += 2; // saltar /*
          while (_pos < fuente.length) {
            if (fuente[_pos] == '\n') {
              _linea++;
              _pos++;
            } else if (fuente[_pos] == '*' &&
                _pos + 1 < fuente.length &&
                fuente[_pos + 1] == '/') {
              _pos += 2; // saltar */
              break;
            } else {
              _pos++;
            }
          }
          continue;
        }
      }

      // Cadena de texto entre comillas
      if (ch == '"') {
        tokens.add(_leerTexto());
        continue;
      }

      // Número positivo
      if (_esDigito(ch)) {
        tokens.add(_leerNumero());
        continue;
      }

      // ── Número negativo: - seguido inmediatamente de dígito ─
      if (ch == '-' &&
          _pos + 1 < fuente.length &&
          _esDigito(fuente[_pos + 1])) {
        tokens.add(_leerNumero(negativo: true));
        continue;
      }

      // Identificador o palabra clave
      if (_esLetra(ch)) {
        tokens.add(_leerPalabra());
        continue;
      }

      // Operadores y puntuación
      switch (ch) {
        case '=':
          if (_pos + 1 < fuente.length && fuente[_pos + 1] == '=') {
            tokens.add(Token(TipoToken.IGUAL, '==', _linea));
            _pos += 2;
          } else {
            tokens.add(Token(TipoToken.ASIGNACION, '=', _linea));
            _pos++;
          }
          break;
        case '>':
          tokens.add(Token(TipoToken.MAYOR, '>', _linea));
          _pos++;
          break;
        case '<':
          tokens.add(Token(TipoToken.MENOR, '<', _linea));
          _pos++;
          break;
        case ':':
          tokens.add(Token(TipoToken.DOS_PUNTOS, ':', _linea));
          _pos++;
          break;
        case '[':
          tokens.add(Token(TipoToken.CORCHETE_IZQ, '[', _linea));
          _pos++;
          break;
        case ']':
          tokens.add(Token(TipoToken.CORCHETE_DER, ']', _linea));
          _pos++;
          break;
        default:
          throw ErrorLexico('Carácter inesperado "$ch" en línea $_linea');
      }
    }

    tokens.add(Token(TipoToken.FIN_ARCHIVO, '', _linea));
    return tokens;
  }

  void _saltarEspacios() {
    while (_pos < fuente.length &&
        fuente[_pos] != '\n' &&
        (fuente[_pos] == ' ' ||
            fuente[_pos] == '\t' ||
            fuente[_pos] == '\r')) {
      _pos++;
    }
  }

  Token _leerTexto() {
    _pos++; // saltar "
    final sb = StringBuffer();
    while (_pos < fuente.length && fuente[_pos] != '"') {
      if (fuente[_pos] == '\n') _linea++;
      sb.write(fuente[_pos]);
      _pos++;
    }
    if (_pos >= fuente.length) {
      throw ErrorLexico('Cadena sin cerrar, línea $_linea');
    }
    _pos++; // saltar "
    return Token(TipoToken.TEXTO, sb.toString(), _linea);
  }

  // negativo: true → consume el '-' inicial también
  Token _leerNumero({bool negativo = false}) {
    final inicio = _pos;
    if (negativo) _pos++; // saltar el '-'
    while (_pos < fuente.length && _esDigito(fuente[_pos])) _pos++;
    final raw = fuente.substring(inicio, _pos); // ej: "-45" o "45"
    return Token(TipoToken.NUMERO, raw, _linea);
  }

  Token _leerPalabra() {
    final inicio = _pos;
    while (_pos < fuente.length &&
        (_esLetra(fuente[_pos]) ||
            _esDigito(fuente[_pos]) ||
            fuente[_pos] == '_')) {
      _pos++;
    }
    final palabra = fuente.substring(inicio, _pos);
    final tipo = _palabrasClave[palabra] ?? TipoToken.IDENTIFICADOR;
    return Token(tipo, palabra, _linea);
  }

  bool _esDigito(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  bool _esLetra(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        c == '_';
  }
}