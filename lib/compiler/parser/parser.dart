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
      case TipoToken.PROGRAMA:
        return '❌ Línea $linea: El programa no empieza con PROGRAMA.\n'
            '👉 La primera línea siempre debe ser:\n'
            '   PROGRAMA "nombre de tu programa"';

      case TipoToken.TEXTO:
        return '❌ Línea $linea: Después de PROGRAMA falta el nombre entre comillas.\n'
            '👉 Escribe el nombre de tu programa entre comillas dobles:\n'
            '   PROGRAMA "Mi robot"';

      case TipoToken.FIN:
        if (encontrado.tipo == TipoToken.FIN_ARCHIVO) {
          return '❌ Línea $linea: El programa nunca se cerró.\n'
              '👉 Al final de todo tu código debes escribir:\n'
              '   FIN PROGRAMA';
        }
        return '❌ Línea $linea: Falta cerrar un bloque con FIN.\n'
            '👉 Revisa que cada SI tenga su FIN SI\n'
            '   y cada REPETIR tenga su FIN REPETIR.';

      case TipoToken.ENTONCES:
        return '❌ Línea $linea: En el SI falta escribir ENTONCES: después de la condición.';

      case TipoToken.DOS_PUNTOS:
        return '❌ Línea $linea: Falta el ":" al final de esta línea.';

      case TipoToken.VECES:
        return '❌ Línea $linea: Después de la expresión falta escribir VECES:';

      case TipoToken.CORCHETE_IZQ:
        return '❌ Línea $linea: Después de REPETIR falta el "[" para encerrar la variable o número.';

      case TipoToken.CORCHETE_DER:
        return '❌ Línea $linea: Falta cerrar el corchete "]" después de la variable o número.';

      case TipoToken.IDENTIFICADOR:
        return '❌ Línea $linea: Se esperaba el nombre de una variable pero encontré $encontradoStr.';

      case TipoToken.NUMERO:
        return '❌ Línea $linea: Se esperaba un número pero encontré $encontradoStr.';

      case TipoToken.ASIGNACION:
        return '❌ Línea $linea: Falta el "=" para asignarle un valor a la variable.';

      default:
        return '❌ Línea $linea: Error inesperado cerca de $encontradoStr.';
    }
  }

  bool _esInicioInstruccion() {
    switch (_actual.tipo) {
      case TipoToken.IDENTIFICADOR:
      case TipoToken.GIRAR:
      case TipoToken.AVANZAR:
      case TipoToken.SI:
      case TipoToken.REPETIR:
      case TipoToken.COMANDO_CUSTOM:
        return true;
      default:
        return false;
    }
  }

  NodoPrograma parsePrograma() {
    _consumir(TipoToken.PROGRAMA);
    final nombre = _consumir(TipoToken.TEXTO).valor;
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.PROGRAMA);
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
      case TipoToken.IDENTIFICADOR: return parseAsignacion();
      case TipoToken.GIRAR:         return parseGirar();
      case TipoToken.AVANZAR:       return parseAvanzar();
      case TipoToken.SI:            return parseCondicional();
      case TipoToken.REPETIR:       return parseCiclo();
      case TipoToken.COMANDO_CUSTOM: return parseCustom();
      default:
        throw ErrorSintactico('😕 Línea ${_actual.linea}: No reconozco la instrucción "${_actual.valor}".');
    }
  }

  NodoCustom parseCustom() {
    final token = _consumir(TipoToken.COMANDO_CUSTOM);
    NodoExpArit? arg;
    
    // Si el siguiente token puede ser una expresión aritmética, lo parseamos como argumento
    if (_es(TipoToken.NUMERO) || 
        _es(TipoToken.IDENTIFICADOR) || 
        _es(TipoToken.PARENTESIS_IZQ) ||
        _es(TipoToken.SEN) || _es(TipoToken.COS) || _es(TipoToken.TANG)) {
      arg = _parseExpArit();
    }
    
    return NodoCustom(token.valor, argumento: arg);
  }

  NodoAsignacion parseAsignacion() {
    final id  = _consumir(TipoToken.IDENTIFICADOR).valor;
    _consumir(TipoToken.ASIGNACION);
    final exp = _parseExpArit();
    return NodoAsignacion(id, exp);
  }

  NodoGirar parseGirar() {
    _consumir(TipoToken.GIRAR);
    final exp = _parseExpArit();
    return NodoGirar(exp);
  }

  NodoAvanzar parseAvanzar() {
    _consumir(TipoToken.AVANZAR);
    final exp = _parseExpArit();
    return NodoAvanzar(exp);
  }

  NodoCondicional parseCondicional() {
    _consumir(TipoToken.SI);
    final condicion = _parseExpBool();
    _consumir(TipoToken.ENTONCES);
    _consumir(TipoToken.DOS_PUNTOS);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.SI);
    return NodoCondicional(condicion, instrucciones);
  }

  NodoCiclo parseCiclo() {
    _consumir(TipoToken.REPETIR);
    _consumir(TipoToken.CORCHETE_IZQ);
    final exp = _parseExpArit();
    _consumir(TipoToken.CORCHETE_DER);
    _consumir(TipoToken.VECES);
    _consumir(TipoToken.DOS_PUNTOS);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.REPETIR);
    return NodoCiclo(exp, instrucciones);
  }

  NodoExpArit _parseExpArit() {
    return _parseTermino();
  }

  NodoExpArit _parseTermino() {
    NodoExpArit nodo = _parseFactor();
    while (_es(TipoToken.MAS) || _es(TipoToken.MENOS)) {
      final op = _consumir(_actual.tipo).valor;
      final der = _parseFactor();
      nodo = NodoOpBinaria(nodo, op, der);
    }
    return nodo;
  }

  NodoExpArit _parseFactor() {
    NodoExpArit nodo = _parsePrimario();
    while (_es(TipoToken.MULTIPLICACION) || _es(TipoToken.DIVISION)) {
      final op = _consumir(_actual.tipo).valor;
      final der = _parsePrimario();
      nodo = NodoOpBinaria(nodo, op, der);
    }
    return nodo;
  }

  NodoExpArit _parsePrimario() {
    if (_es(TipoToken.NUMERO)) {
      return NodoNumero(double.parse(_consumir(TipoToken.NUMERO).valor));
    }
    if (_es(TipoToken.IDENTIFICADOR)) {
      return NodoVariable(_consumir(TipoToken.IDENTIFICADOR).valor);
    }
    if (_es(TipoToken.SEN) || _es(TipoToken.COS) || _es(TipoToken.TANG)) {
      final func = _consumir(_actual.tipo).valor;
      _consumir(TipoToken.PARENTESIS_IZQ);
      final arg = _parseExpArit();
      _consumir(TipoToken.PARENTESIS_DER);
      return NodoFuncTrig(func, arg);
    }
    if (_es(TipoToken.PARENTESIS_IZQ)) {
      _consumir(TipoToken.PARENTESIS_IZQ);
      final exp = _parseExpArit();
      _consumir(TipoToken.PARENTESIS_DER);
      return exp;
    }
    throw ErrorSintactico('❌ Línea ${_actual.linea}: Se esperaba un número, variable o función.');
  }

  NodoExpBool _parseExpBool() {
    final izq = _parseExpArit();
    final comp = _parseComparador();
    final der = _parseExpArit();
    return NodoComparacion(izq, comp, der);
  }

  String _parseComparador() {
    if (_es(TipoToken.IGUAL)) { _pos++; return '=='; }
    if (_es(TipoToken.MAYOR)) { _pos++; return '>'; }
    if (_es(TipoToken.MENOR)) { _pos++; return '<'; }
    throw ErrorSintactico('❌ Línea ${_actual.linea}: Se esperaba un comparador (<, >, ==).');
  }
}
