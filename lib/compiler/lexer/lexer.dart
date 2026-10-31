import '../models/token.dart';

class ErrorLexico implements Exception {
  final String mensaje;
  ErrorLexico(this.mensaje);
  @override
  String toString() => mensaje;
}

class AnalizadorLexico {
  final String fuente;
  final List<String> comandosPersonalizados;
  int _pos = 0;
  int _linea = 1;

  static const Map<String, TipoToken> _palabrasClave = {
    'PROGRAMA': TipoToken.programa,
    'FIN':      TipoToken.fin,
    'GIRAR':    TipoToken.girar,
    'AVANZAR':  TipoToken.avanzar,
    'SI':       TipoToken.si,
    'ENTONCES': TipoToken.entonces,
    'REPETIR':  TipoToken.repetir,
    'VECES':    TipoToken.veces,
    'SEN':  TipoToken.sen,
    'COS':  TipoToken.cos,
    'TANG': TipoToken.tang,
    'AND':  TipoToken.and,
    'OR':   TipoToken.or,
    'NOT':  TipoToken.not,
  };

  AnalizadorLexico(this.fuente, {this.comandosPersonalizados = const []});

  List<Token> tokenizar() {
    final tokens = <Token>[];

    while (_pos < fuente.length) {
      _saltarEspacios();
      if (_pos >= fuente.length) break;

      final ch = fuente[_pos];

      if (ch == '\n') {
        _linea++;
        _pos++;
        continue;
      }

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
            if (fuente[_pos] == '\n') {
              _linea++;
              _pos++;
            } else if (fuente[_pos] == '*' &&
                _pos + 1 < fuente.length &&
                fuente[_pos + 1] == '/') {
              _pos += 2;
              break;
            } else {
              _pos++;
            }
          }
          continue;
        }
      }

      if (ch == '"') {
        tokens.add(_leerTexto());
        continue;
      }

      if (_esDigito(ch)) {
        tokens.add(_leerNumero());
        continue;
      }

      if (_esLetra(ch)) {
        tokens.add(_leerPalabra());
        continue;
      }

      switch (ch) {
        case '+':
          tokens.add(Token(TipoToken.mas, '+', _linea));
          _pos++;
          break;
        case '-':
        // Si el '-' está seguido de un dígito, se lee como número negativo
          if (_pos + 1 < fuente.length && _esDigito(fuente[_pos + 1])) {
            tokens.add(_leerNumero(negativo: true));
          } else {
            tokens.add(Token(TipoToken.menos, '-', _linea));
            _pos++;
          }
          break;
        case '*':
          tokens.add(Token(TipoToken.multiplicacion, '*', _linea));
          _pos++;
          break;
        case '/':
          tokens.add(Token(TipoToken.division, '/', _linea));
          _pos++;
          break;
        case '=':
          if (_pos + 1 < fuente.length && fuente[_pos + 1] == '=') {
            tokens.add(Token(TipoToken.igual, '==', _linea));
            _pos += 2;
          } else {
            tokens.add(Token(TipoToken.asignacion, '=', _linea));
            _pos++;
          }
          break;
        case '>':
          tokens.add(Token(TipoToken.mayor, '>', _linea));
          _pos++;
          break;
        case '<':
          tokens.add(Token(TipoToken.menor, '<', _linea));
          _pos++;
          break;
        case ':':
          tokens.add(Token(TipoToken.dosPuntos, ':', _linea));
          _pos++;
          break;
        case '[':
          tokens.add(Token(TipoToken.corcheteIzq, '[', _linea));
          _pos++;
          break;
        case ']':
          tokens.add(Token(TipoToken.corcheteDer, ']', _linea));
          _pos++;
          break;
        case '(':
          tokens.add(Token(TipoToken.parentesisIzq, '(', _linea));
          _pos++;
          break;
        case ')':
          tokens.add(Token(TipoToken.parentesisDer, ')', _linea));
          _pos++;
          break;
        default:
          throw ErrorLexico(
              '❌ Ups, en la línea $_linea hay un símbolo que no conozco: "$ch"\n'
                  '👉 Usa solo letras (sin tildes ni ñ), números y los signos = < > : [ ] ( )'
          );
      }
    }

    tokens.add(Token(TipoToken.finArchivo, '', _linea));
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
    final lineaApertura = _linea;
    _pos++;
    final sb = StringBuffer();
    while (_pos < fuente.length && fuente[_pos] != '"') {
      if (fuente[_pos] == '\n') _linea++;
      sb.write(fuente[_pos]);
      _pos++;
    }
    if (_pos >= fuente.length) {
      throw ErrorLexico(
          '❌ Ups, en la línea $lineaApertura abriste comillas " pero nunca las cerraste.\n'
              '👉 Las comillas siempre se abren y se cierran: "Mi robot"');
    }
    _pos++;
    return Token(TipoToken.texto, sb.toString(), _linea);
  }

  Token _leerNumero({bool negativo = false}) {
    final inicio = _pos;
    if (negativo) _pos++;
    while (_pos < fuente.length && _esDigito(fuente[_pos])) {
      _pos++;
    }
    if (_pos < fuente.length && fuente[_pos] == '.') {
      _pos++;
      while (_pos < fuente.length && _esDigito(fuente[_pos])) {
      _pos++;
    }
    }
    final raw = fuente.substring(inicio, _pos);
    return Token(TipoToken.numero, raw, _linea);
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
    final enMayusculas = palabra.toUpperCase();
    
    if (_palabrasClave.containsKey(enMayusculas)) {
      return Token(_palabrasClave[enMayusculas]!, enMayusculas, _linea);
    }
    
    if (comandosPersonalizados.contains(enMayusculas)) {
      return Token(TipoToken.comandoCustom, enMayusculas, _linea);
    }

    return Token(TipoToken.identificador, palabra, _linea);
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