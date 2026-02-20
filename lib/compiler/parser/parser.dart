import '../models/token.dart';
import '../ast/nodes.dart';

class ErrorSintactico implements Exception {
  final String mensaje;
  ErrorSintactico(this.mensaje);
  @override
  String toString() => '❌ Error Sintáctico: $mensaje';
}

class Parser {
  final List<Token> tokens;
  int _pos = 0;

  Parser(this.tokens);

  Token get _actual => tokens[_pos];
  bool _es(TipoToken tipo) => _actual.tipo == tipo;

  Token _consumir(TipoToken tipo) {
    if (_actual.tipo != tipo) {
      throw ErrorSintactico(
          'Se esperaba ${tipo.name} pero se encontró '
              '${_actual.tipo.name} ("${_actual.valor}") en línea ${_actual.linea}');
    }
    return tokens[_pos++];
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

  // ── Reglas de gramática ──────────────────────────────────────

  NodoPrograma parsePrograma() {
    _consumir(TipoToken.PROGRAMA);
    final nombre = _consumir(TipoToken.TEXTO).valor;
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.PROGRAMA);
    if (!_es(TipoToken.FIN_ARCHIVO)) {
      throw ErrorSintactico(
          'Código después de FIN PROGRAMA en línea ${_actual.linea}');
    }
    return NodoPrograma(nombre, instrucciones);
  }

  NodoInstrucciones parseInstrucciones() {
    final lista = <Nodo>[];
    while (_esInicioInstruccion()) {
      lista.add(parseInstruccion());
    }
    if (lista.isEmpty) {
      throw ErrorSintactico(
          'Se esperaba al menos una instrucción en línea ${_actual.linea}');
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
            'Instrucción desconocida "${_actual.valor}" en línea ${_actual.linea}');
    }
  }

  NodoAsignacion parseAsignacion() {
    final id  = _consumir(TipoToken.IDENTIFICADOR).valor;
    _consumir(TipoToken.ASIGNACION);
    final num = int.parse(_consumir(TipoToken.NUMERO).valor);
    return NodoAsignacion(id, num);
  }

  NodoGirar parseGirar() {
    _consumir(TipoToken.GIRAR);
    final num = int.parse(_consumir(TipoToken.NUMERO).valor);
    return NodoGirar(num);
  }

  NodoAvanzar parseAvanzar() {
    _consumir(TipoToken.AVANZAR);
    final num = int.parse(_consumir(TipoToken.NUMERO).valor);
    return NodoAvanzar(num);
  }

  NodoCondicional parseCondicional() {
    _consumir(TipoToken.SI);
    final condicion = parseCondicion();
    _consumir(TipoToken.ENTONCES);
    _consumir(TipoToken.DOS_PUNTOS);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.SI);
    return NodoCondicional(condicion, instrucciones);
  }

  NodoCiclo parseCiclo() {
    _consumir(TipoToken.REPETIR);
    String? identificador;
    if (_es(TipoToken.CORCHETE_IZQ)) {
      _consumir(TipoToken.CORCHETE_IZQ);
      identificador = _consumir(TipoToken.IDENTIFICADOR).valor;
      _consumir(TipoToken.CORCHETE_DER);
    }
    _consumir(TipoToken.VECES);
    _consumir(TipoToken.DOS_PUNTOS);
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.REPETIR);
    return NodoCiclo(identificador, instrucciones);
  }

  NodoCondicion parseCondicion() {
    final id   = _consumir(TipoToken.IDENTIFICADOR).valor;
    final comp = parseComparador();
    final num  = int.parse(_consumir(TipoToken.NUMERO).valor);
    return NodoCondicion(id, comp, num);
  }

  String parseComparador() {
    if (_es(TipoToken.IGUAL)) { _pos++; return '=='; }
    if (_es(TipoToken.MAYOR)) { _pos++; return '>'; }
    if (_es(TipoToken.MENOR)) { _pos++; return '<'; }
    throw ErrorSintactico(
        'Se esperaba comparador (==, >, <) pero se encontró '
            '"${_actual.valor}" en línea ${_actual.linea}');
  }
}