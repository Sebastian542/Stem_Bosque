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
    if (_actual.tipo != tipo) {
      throw ErrorSintactico(_mensajeError(tipo, _actual));
    }
    return tokens[_pos++];
  }

  String _mensajeError(TipoToken esperado, Token encontrado) {
    final linea = encontrado.linea;
    final encontradoStr = encontrado.valor.isEmpty
        ? 'el final del archivo'
        : '"${encontrado.valor}"';

    switch (esperado) {
      case TipoToken.programa:
        return '❌ Línea $linea: El programa no empieza con PROGRAMA.\n'
            '👉 La primera línea siempre debe ser:\n'
            '   PROGRAMA "nombre de tu programa"';

      case TipoToken.texto:
        return '❌ Línea $linea: Después de PROGRAMA falta el nombre entre comillas.\n'
            '👉 Escribe el nombre de tu programa entre comillas dobles:\n'
            '   PROGRAMA "Mi robot"';

      case TipoToken.fin:
        if (encontrado.tipo == TipoToken.finArchivo) {
          return '❌ Línea $linea: El programa nunca se cerró.\n'
              '👉 Al final de todo tu código debes escribir:\n'
              '   FIN PROGRAMA';
        }
        return '❌ Línea $linea: Falta cerrar un bloque con FIN.\n'
            '👉 Revisa que cada SI tenga su FIN SI\n'
            '   y cada REPETIR tenga su FIN REPETIR.';

      case TipoToken.entonces:
        return '❌ Línea $linea: En el SI falta escribir ENTONCES: después de la condición.';

      case TipoToken.dosPuntos:
        return '❌ Línea $linea: Falta el ":" al final de esta línea.';

      case TipoToken.veces:
        return '❌ Línea $linea: Después de la expresión falta escribir VECES:';

      case TipoToken.corcheteIzq:
        return '❌ Línea $linea: Después de REPETIR falta el "[" para encerrar la variable o número.';

      case TipoToken.corcheteDer:
        return '❌ Línea $linea: Falta cerrar el corchete "]" después de la variable o número.';

      case TipoToken.identificador:
        return '❌ Línea $linea: Se esperaba el nombre de una variable pero encontré $encontradoStr.';

      case TipoToken.numero:
        return '❌ Línea $linea: Se esperaba un número pero encontré $encontradoStr.';

      case TipoToken.asignacion:
        return '❌ Línea $linea: Falta el "=" para asignarle un valor a la variable.';

      default:
        return '❌ Línea $linea: Error inesperado cerca de $encontradoStr.';
    }
  }

  bool _esInicioInstruccion() {
    switch (_actual.tipo) {
      case TipoToken.identificador:
      case TipoToken.girar:
      case TipoToken.avanzar:
      case TipoToken.si:
      case TipoToken.repetir:
      case TipoToken.comandoCustom:
        return true;
      default:
        return false;
    }
  }

  NodoPrograma parsePrograma() {
    _consumir(TipoToken.programa);
    final nombre = _consumir(TipoToken.texto).valor;
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.fin);
    _consumir(TipoToken.programa);
    return NodoPrograma(nombre, instrucciones);
  }

  NodoInstrucciones parseInstrucciones() {
    final lista = <Nodo>[];
    while (_esInicioInstruccion()) {
      lista.add(parseInstruccion());
    }
    return NodoInstrucciones(lista);
  }

  Nodo parseInstruccion() {
    switch (_actual.tipo) {
      case TipoToken.identificador: return parseAsignacion();
      case TipoToken.girar:         return parseGirar();
      case TipoToken.avanzar:       return parseAvanzar();
      case TipoToken.si:            return parseCondicional();
      case TipoToken.repetir:       return parseCiclo();
      case TipoToken.comandoCustom: return parseCustom();
      default:
        throw ErrorSintactico('😕 Línea ${_actual.linea}: No reconozco la instrucción "${_actual.valor}".');
    }
  }

  NodoCustom parseCustom() {
    final token = _consumir(TipoToken.comandoCustom);
    NodoExpArit? arg;
    
    // Si el siguiente token puede ser una expresión aritmética, lo parseamos como argumento
    if (_es(TipoToken.numero) || 
        _es(TipoToken.identificador) || 
        _es(TipoToken.parentesisIzq) ||
        _es(TipoToken.sen) || _es(TipoToken.cos) || _es(TipoToken.tang)) {
      arg = _parseExpArit();
    }
    
    return NodoCustom(token.valor, argumento: arg);
  }

  NodoAsignacion parseAsignacion() {
    final id  = _consumir(TipoToken.identificador).valor;
    _consumir(TipoToken.asignacion);
    final exp = _parseExpArit();
    return NodoAsignacion(id, exp);
  }

  NodoGirar parseGirar() {
    _consumir(TipoToken.girar);
    final exp = _parseExpArit();
    return NodoGirar(exp);
  }

  NodoAvanzar parseAvanzar() {
    _consumir(TipoToken.avanzar);
    final exp = _parseExpArit();
    return NodoAvanzar(exp);
  }

  NodoCondicional parseCondicional() {
    _consumir(TipoToken.si);
    final condicion = _parseExpBool();
    _consumir(TipoToken.entonces);
    _consumir(TipoToken.dosPuntos);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.fin);
    _consumir(TipoToken.si);
    return NodoCondicional(condicion, instrucciones);
  }

  NodoCiclo parseCiclo() {
    _consumir(TipoToken.repetir);
    _consumir(TipoToken.corcheteIzq);
    final exp = _parseExpArit();
    _consumir(TipoToken.corcheteDer);
    _consumir(TipoToken.veces);
    _consumir(TipoToken.dosPuntos);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.fin);
    _consumir(TipoToken.repetir);
    return NodoCiclo(exp, instrucciones);
  }

  NodoExpArit _parseExpArit() {
    return _parseTermino();
  }

  NodoExpArit _parseTermino() {
    NodoExpArit nodo = _parseFactor();
    while (_es(TipoToken.mas) || _es(TipoToken.menos)) {
      final op = _consumir(_actual.tipo).valor;
      final der = _parseFactor();
      nodo = NodoOpBinaria(nodo, op, der);
    }
    return nodo;
  }

  NodoExpArit _parseFactor() {
    NodoExpArit nodo = _parsePrimario();
    while (_es(TipoToken.multiplicacion) || _es(TipoToken.division)) {
      final op = _consumir(_actual.tipo).valor;
      final der = _parsePrimario();
      nodo = NodoOpBinaria(nodo, op, der);
    }
    return nodo;
  }

  NodoExpArit _parsePrimario() {
    if (_es(TipoToken.numero)) {
      return NodoNumero(double.parse(_consumir(TipoToken.numero).valor));
    }
    if (_es(TipoToken.identificador)) {
      return NodoVariable(_consumir(TipoToken.identificador).valor);
    }
    if (_es(TipoToken.sen) || _es(TipoToken.cos) || _es(TipoToken.tang)) {
      final func = _consumir(_actual.tipo).valor;
      _consumir(TipoToken.parentesisIzq);
      final arg = _parseExpArit();
      _consumir(TipoToken.parentesisDer);
      return NodoFuncTrig(func, arg);
    }
    if (_es(TipoToken.parentesisIzq)) {
      _consumir(TipoToken.parentesisIzq);
      final exp = _parseExpArit();
      _consumir(TipoToken.parentesisDer);
      return exp;
    }
    throw ErrorSintactico('❌ Línea ${_actual.linea}: Se esperaba un número, variable o función.');
  }

  NodoExpBool _parseExpBool() {
    return _parseOr();
  }

  NodoExpBool _parseOr() {
    NodoExpBool nodo = _parseAnd();
    while (_es(TipoToken.or)) {
      _pos++;
      final der = _parseAnd();
      nodo = NodoOr(nodo, der);
    }
    return nodo;
  }

  NodoExpBool _parseAnd() {
    NodoExpBool nodo = _parseNot();
    while (_es(TipoToken.and)) {
      _pos++;
      final der = _parseNot();
      nodo = NodoAnd(nodo, der);
    }
    return nodo;
  }

  NodoExpBool _parseNot() {
    if (_es(TipoToken.not)) {
      _pos++;
      final exp = _parseNot();
      return NodoNot(exp);
    }
    return _parseComparacion();
  }

  NodoExpBool _parseComparacion() {
    final izq = _parseExpArit();
    final comp = _parseComparador();
    final der = _parseExpArit();
    return NodoComparacion(izq, comp, der);
  }

  String _parseComparador() {
    if (_es(TipoToken.igual)) { _pos++; return '=='; }
    if (_es(TipoToken.mayor)) { _pos++; return '>'; }
    if (_es(TipoToken.menor)) { _pos++; return '<'; }
    throw ErrorSintactico('❌ Línea ${_actual.linea}: Se esperaba un comparador (<, >, ==).');
  }
}
