import '../models/token.dart';
import '../ast/nodes.dart';

class ErrorSintactico implements Exception {
  final String mensaje;
  ErrorSintactico(this.mensaje);
  @override
  String toString() => mensaje;
}

class Parser {
  final List<Token> tokens;
  int _pos = 0;

  Parser(this.tokens);

  Token get _actual => tokens[_pos];
  bool _es(TipoToken tipo) => _actual.tipo == tipo;

  Token _consumir(TipoToken tipo) {
    if (_actual.tipo != tipo) throw ErrorSintactico(_mensajeError(tipo, _actual));
    return tokens[_pos++];
  }

  String _mensajeError(TipoToken esperado, Token encontrado) {
    final linea = encontrado.linea;
    final enc = encontrado.valor.isEmpty ? 'el final del programa' : '"${encontrado.valor}"';
    switch (esperado) {
      case TipoToken.PROGRAMA:
        return '😕 Línea $linea: Tu programa debe comenzar con PROGRAMA.\n💡 Ejemplo: PROGRAMA "Mi robot"';
      case TipoToken.FIN:
        return '😕 Línea $linea: Falta FIN para cerrar un bloque.\n💡 Cada SI y REPETIR necesitan su FIN.';
      case TipoToken.TEXTO:
        return '😕 Línea $linea: Después de PROGRAMA pon el nombre entre comillas.\n💡 Ejemplo: PROGRAMA "Mi robot"';
      case TipoToken.ENTONCES:
        return '😕 Línea $linea: Falta ENTONCES después de la condición.\n💡 Ejemplo: SI N < 10 ENTONCES:';
      case TipoToken.DOS_PUNTOS:
        return '😕 Línea $linea: Falta ":" al final de la línea.\n💡 ENTONCES: y VECES: siempre llevan dos puntos.';
      case TipoToken.VECES:
        return '😕 Línea $linea: Falta VECES después de los corchetes.\n💡 Ejemplo: REPETIR [N] VECES:';
      case TipoToken.CORCHETE_IZQ:
        return '😕 Línea $linea: Falta "[" antes de la expresión.\n💡 Ejemplo: REPETIR [N * 2] VECES:';
      case TipoToken.CORCHETE_DER:
        return '😕 Línea $linea: Falta "]" para cerrar.\n💡 Ejemplo: REPETIR [N] VECES:';
      case TipoToken.PAREN_DER:
        return '😕 Línea $linea: Falta ")" para cerrar el paréntesis.\n💡 Ejemplo: SI (N < 10 AND M > 5) ENTONCES:';
      case TipoToken.NUMERO:
        return '😕 Línea $linea: Se necesita un número pero encontré $enc.\n💡 Ejemplo: GIRAR 90';
      case TipoToken.IDENTIFICADOR:
        return '😕 Línea $linea: Se esperaba una variable pero encontré $enc.\n💡 Los nombres solo tienen letras y números.';
      case TipoToken.ASIGNACION:
        return '😕 Línea $linea: Falta "=" para asignar valor.\n💡 Ejemplo: N = 10';
      default:
        return '😕 Línea $linea: Algo no está bien cerca de $enc.\n💡 Revisa las palabras y el orden.';
    }
  }

  bool _esInicioInstruccion() {
    switch (_actual.tipo) {
      case TipoToken.IDENTIFICADOR:
      case TipoToken.GIRAR:
      case TipoToken.AVANZAR:
      case TipoToken.SI:
      case TipoToken.REPETIR:
        return true;
      default:
        return false;
    }
  }

  // ── Programa ──────────────────────────────────────────────────

  NodoPrograma parsePrograma() {
    _consumir(TipoToken.PROGRAMA);
    final nombre = _consumir(TipoToken.TEXTO).valor;
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.PROGRAMA);
    if (!_es(TipoToken.FIN_ARCHIVO)) {
      throw ErrorSintactico(
          '😕 Línea ${_actual.linea}: Hay código después de FIN PROGRAMA.\n'
              '💡 FIN PROGRAMA debe ser lo último.'
      );
    }
    return NodoPrograma(nombre, instrucciones);
  }

  NodoInstrucciones parseInstrucciones() {
    final lista = <Nodo>[];
    while (_esInicioInstruccion()) lista.add(parseInstruccion());
    if (lista.isEmpty) {
      final linea = _actual.linea;
      if (_actual.tipo == TipoToken.FIN) {
        throw ErrorSintactico(
            '😕 Línea $linea: ¡Este bloque está vacío!\n'
                '💡 Pon al menos una instrucción dentro del SI o REPETIR.'
        );
      }
      if (_actual.tipo == TipoToken.FIN_ARCHIVO) {
        throw ErrorSintactico(
            '😕 Línea $linea: El programa termina sin instrucciones.\n'
                '💡 Agrega al menos un GIRAR o AVANZAR.'
        );
      }
      throw ErrorSintactico(
          '😕 Línea $linea: Se esperaba una instrucción pero encontré "${_actual.valor}".\n'
              '💡 Instrucciones válidas: GIRAR, AVANZAR, SI, REPETIR, o una variable.'
      );
    }
    return NodoInstrucciones(lista);
  }

  Nodo parseInstruccion() {
    switch (_actual.tipo) {
      case TipoToken.IDENTIFICADOR: return parseAsignacion();
      case TipoToken.GIRAR:         return parseGirar();
      case TipoToken.AVANZAR:       return parseAvanzar();
      case TipoToken.SI:            return parseCondicional();
      case TipoToken.REPETIR:       return parseCiclo();
      default:
        throw ErrorSintactico(
            '😕 Línea ${_actual.linea}: No reconozco "${_actual.valor}".\n'
                '💡 Instrucciones válidas: GIRAR, AVANZAR, SI, REPETIR, o una variable.'
        );
    }
  }

  // ── Instrucciones ─────────────────────────────────────────────

  NodoAsignacion parseAsignacion() {
    final id = _consumir(TipoToken.IDENTIFICADOR).valor;
    _consumir(TipoToken.ASIGNACION);
    final exp = parseExpArit();
    return NodoAsignacion(id, exp);
  }

  NodoGirar parseGirar() {
    _consumir(TipoToken.GIRAR);
    return NodoGirar(parseExpArit());
  }

  NodoAvanzar parseAvanzar() {
    _consumir(TipoToken.AVANZAR);
    return NodoAvanzar(parseExpArit());
  }

  NodoCondicional parseCondicional() {
    _consumir(TipoToken.SI);
    final condicion = parseExpBool();
    _consumir(TipoToken.ENTONCES);
    _consumir(TipoToken.DOS_PUNTOS);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.SI);
    return NodoCondicional(condicion, instrucciones);
  }

  NodoCiclo parseCiclo() {
    _consumir(TipoToken.REPETIR);
    if (!_es(TipoToken.CORCHETE_IZQ)) {
      throw ErrorSintactico(
          '😕 Línea ${_actual.linea}: Después de REPETIR pon la expresión entre corchetes.\n'
              '💡 Ejemplo: REPETIR [N * 2] VECES:'
      );
    }
    _consumir(TipoToken.CORCHETE_IZQ);
    final exp = parseExpArit();
    _consumir(TipoToken.CORCHETE_DER);
    _consumir(TipoToken.VECES);
    _consumir(TipoToken.DOS_PUNTOS);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.REPETIR);
    return NodoCiclo(exp, instrucciones);
  }

  // ── Expresiones booleanas (OR < AND < NOT) ────────────────────

  NodoExpBool parseExpBool() {
    NodoExpBool izq = parseExpAnd();
    while (_es(TipoToken.OR)) {
      _pos++;
      izq = NodoOr(izq, parseExpAnd());
    }
    return izq;
  }

  NodoExpBool parseExpAnd() {
    NodoExpBool izq = parseExpNot();
    while (_es(TipoToken.AND)) {
      _pos++;
      izq = NodoAnd(izq, parseExpNot());
    }
    return izq;
  }

  NodoExpBool parseExpNot() {
    if (_es(TipoToken.NOT)) { _pos++; return NodoNot(parseExpNot()); }
    return parseAtomoBool();
  }

  NodoExpBool parseAtomoBool() {
    if (_es(TipoToken.PAREN_IZQ)) {
      _pos++;
      final exp = parseExpBool();
      _consumir(TipoToken.PAREN_DER);
      return exp;
    }
    // Comparación: expArit comparador expArit
    final izq  = parseExpArit();
    final comp = parseComparador();
    final der  = parseExpArit();
    return NodoComparacion(izq, comp, der);
  }

  String parseComparador() {
    if (_es(TipoToken.IGUAL)) { _pos++; return '=='; }
    if (_es(TipoToken.MAYOR)) { _pos++; return '>'; }
    if (_es(TipoToken.MENOR)) { _pos++; return '<'; }
    throw ErrorSintactico(
        '😕 Línea ${_actual.linea}: Necesito un comparador (==, >, <) pero encontré "${_actual.valor}".\n'
            '💡 Ejemplo: SI N < 10 ENTONCES:'
    );
  }

  // ── Expresiones aritméticas ───────────────────────────────────
  // Precedencia: + - < * / % < ^ < unario/trig < átomo

  /// Nivel 1 — suma y resta
  NodoExpArit parseExpArit() {
    NodoExpArit izq = parseExpMult();
    while (_es(TipoToken.SUMA) || _es(TipoToken.RESTA)) {
      final op = _actual.valor;
      _pos++;
      izq = NodoOpBinaria(izq, op, parseExpMult());
    }
    return izq;
  }

  /// Nivel 2 — multiplicación, división, módulo
  NodoExpArit parseExpMult() {
    NodoExpArit izq = parseExpPot();
    while (_es(TipoToken.MULT) || _es(TipoToken.DIV) || _es(TipoToken.MODULO)) {
      final op = _actual.valor;
      _pos++;
      izq = NodoOpBinaria(izq, op, parseExpPot());
    }
    return izq;
  }

  /// Nivel 3 — potencia (asociativa a la derecha)
  NodoExpArit parseExpPot() {
    final base = parseExpUnaria();
    if (_es(TipoToken.POTENCIA)) {
      _pos++;
      return NodoOpBinaria(base, '^', parseExpPot()); // recursión derecha
    }
    return base;
  }

  /// Nivel 4 — negación unaria y funciones trigonométricas
  NodoExpArit parseExpUnaria() {
    if (_es(TipoToken.RESTA)) {
      _pos++;
      return NodoNegUnaria(parseExpUnaria());
    }
    if (_es(TipoToken.SEN) || _es(TipoToken.COS) || _es(TipoToken.TANG)) {
      final fn = _actual.valor;
      _pos++;
      return NodoFuncTrig(fn, parseAtomoArit());
    }
    return parseAtomoArit();
  }

  /// Nivel 5 — átomo: número, variable o paréntesis
  NodoExpArit parseAtomoArit() {
    if (_es(TipoToken.NUMERO)) {
      final val = double.parse(_actual.valor);
      _pos++;
      return NodoNumero(val);
    }
    if (_es(TipoToken.IDENTIFICADOR)) {
      final nombre = _actual.valor;
      _pos++;
      return NodoVariable(nombre);
    }
    if (_es(TipoToken.PAREN_IZQ)) {
      _pos++;
      final exp = parseExpArit();
      _consumir(TipoToken.PAREN_DER);
      return exp;
    }
    throw ErrorSintactico(
        '😕 Línea ${_actual.linea}: Se esperaba un número o variable pero encontré "${_actual.valor}".\n'
            '💡 Ejemplo: N + 5  o  SEN 90  o  (N * 2)'
    );
  }
}