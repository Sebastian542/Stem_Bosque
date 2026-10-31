import 'dart:math' show min;
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

  /// Mensajes pensados para niños: cortos, con palabras simples y siempre en
  /// dos partes: qué pasó (❌) y qué hacer (👉). El ejemplo de cómo se escribe
  /// bien lo agrega SyntaxValidator (ver syntax_help.dart).
  String _mensajeError(TipoToken esperado, Token encontrado) {
    const faltaAlFinalDeLinea = {
      TipoToken.texto,
      TipoToken.entonces,
      TipoToken.dosPuntos,
      TipoToken.veces,
      TipoToken.corcheteDer,
      TipoToken.parentesisIzq,
      TipoToken.parentesisDer,
    };
    final previo = _pos > 0 ? tokens[_pos - 1] : encontrado;
    final linea = (faltaAlFinalDeLinea.contains(esperado) &&
            previo.linea < encontrado.linea)
        ? previo.linea
        : encontrado.linea;

    final encontradoStr = encontrado.valor.isEmpty
        ? 'el final del archivo'
        : '"${encontrado.valor}"';

    switch (esperado) {
      case TipoToken.programa:
        if (_pos > 1) {
          return '❌ Ups, en la línea $linea falta el final del programa.\n'
              '👉 La última línea tiene que ser: FIN PROGRAMA';
        }
        return '❌ Ups, en la línea $linea el programa tiene que empezar con la palabra PROGRAMA.\n'
            '👉 Escribe en la primera línea: PROGRAMA "Mi robot"';

      case TipoToken.texto:
        return '❌ Ups, en la línea $linea a PROGRAMA le falta el nombre.\n'
            '👉 Ponle un nombre entre comillas, por ejemplo: PROGRAMA "Mi robot"';

      case TipoToken.fin:
        if (encontrado.tipo == TipoToken.finArchivo) {
          return '❌ Ups, en la línea $linea falta el final del programa.\n'
              '👉 Cuando termines, escribe en la última línea: FIN PROGRAMA';
        }
        return '❌ Ups, en la línea $linea falta cerrar un bloque con FIN.\n'
            '👉 Revisa que cada SI tenga su FIN SI y cada REPETIR su FIN REPETIR.';

      case TipoToken.entonces:
        return '❌ Ups, en la línea $linea al SI le falta la palabra ENTONCES.\n'
            '👉 Después de la condición escribe: ENTONCES:';

      case TipoToken.dosPuntos:
        return '❌ Ups, en la línea $linea faltan los dos puntos ( : ) al final.\n'
            '👉 ENTONCES y VECES siempre terminan con dos puntos pegados: ENTONCES:  VECES:';

      case TipoToken.veces:
        return '❌ Ups, en la línea $linea al REPETIR le falta la palabra VECES.\n'
            '👉 Se escribe así: REPETIR [N] VECES:';

      case TipoToken.corcheteIzq:
        return '❌ Ups, en la línea $linea falta abrir el corchete [ después de REPETIR.\n'
            '👉 El número o la variable va entre corchetes: REPETIR [N] VECES:';

      case TipoToken.corcheteDer:
        return '❌ Ups, en la línea $linea falta cerrar el corchete ] .\n'
            '👉 Se escribe así: REPETIR [N] VECES:';

      case TipoToken.identificador:
        if (encontrado.tipo == TipoToken.numero) {
          return '❌ Ups, en la línea $linea pusiste un número donde iba un nombre.\n'
              '👉 Los nombres se escriben con letras, por ejemplo: N, Pasos, Contador';
        }
        return '❌ Ups, en la línea $linea esperaba un nombre y encontré $encontradoStr.\n'
            '👉 Los nombres llevan letras y números, sin espacios: N, Pasos, Vel2';

      case TipoToken.numero:
        return '❌ Ups, en la línea $linea esperaba un número y encontré $encontradoStr.\n'
            '👉 Puedes usar un número, una variable o SEN, COS y TANG.';

      case TipoToken.asignacion:
        return '❌ Ups, en la línea $linea escribiste "${encontrado.valor}" solo y falta completarlo.\n'
            '👉 Para guardar un número escribe: ${encontrado.valor} = 10';

      case TipoToken.si:
        return '❌ Ups, en la línea $linea el SI no se cerró: aquí esperaba FIN SI.\n'
            '👉 Cierra el SI con FIN SI antes de seguir.';

      case TipoToken.repetir:
        return '❌ Ups, en la línea $linea el REPETIR no se cerró: aquí esperaba FIN REPETIR.\n'
            '👉 Cierra el REPETIR con FIN REPETIR antes de seguir.';

      case TipoToken.parentesisIzq:
        return '❌ Ups, en la línea $linea falta el paréntesis ( después del nombre de la función.\n'
            '👉 El paréntesis va pegado al nombre: SEN(90)';

      case TipoToken.parentesisDer:
        return '❌ Ups, en la línea $linea falta cerrar el paréntesis ) de la función.\n'
            '👉 El ángulo va entre paréntesis: SEN(90)';

      default:
        return '❌ Ups, en la línea $linea no entendí lo que escribiste cerca de $encontradoStr.\n'
            '👉 Puedes usar: GIRAR, AVANZAR, SI, REPETIR, AND, OR, NOT, o el nombre de una variable.';
    }
  }

  int _distancia(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        final costo = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur.add(min(min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + costo));
      }
      prev = cur;
    }
    return prev[b.length];
  }

  String? _ordenParecida(String palabra) {
    final p = palabra.toUpperCase();
    if (p.length < 4) return null;
    final tope = p.length >= 7 ? 2 : 1;
    String? mejor;
    var mejorDist = tope + 1;
    for (final k in const [
      'AVANZAR',
      'GIRAR',
      'REPETIR',
      'PROGRAMA',
      'ENTONCES',
      'VECES',
    ]) {
      final d = _distancia(p, k);
      if (d <= tope && d < mejorDist) {
        mejor = k;
        mejorDist = d;
      }
    }
    return mejor;
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

    if (_es(TipoToken.si)) {
      throw ErrorSintactico(
        '❌ Ups, en la línea ${_actual.linea} escribiste FIN SI pero no hay ningún SI abierto.\n'
            '👉 Borra esa línea, o agrega el SI que falta antes.',
      );
    }
    if (_es(TipoToken.repetir)) {
      throw ErrorSintactico(
        '❌ Ups, en la línea ${_actual.linea} escribiste FIN REPETIR pero no hay ningún REPETIR abierto.\n'
            '👉 Borra esa línea, o agrega el REPETIR que falta antes.',
      );
    }

    _consumir(TipoToken.programa);

    if (!_es(TipoToken.finArchivo)) {
      throw ErrorSintactico(
          '❌ Ups, en la línea ${_actual.linea} hay texto después de FIN PROGRAMA.\n'
              '👉 FIN PROGRAMA tiene que ser lo último. Borra o mueve lo que sigue.');
    }

    return NodoPrograma(nombre, instrucciones);
  }

  NodoInstrucciones parseInstrucciones({int? lineaApertura}) {
    final lista = <Nodo>[];
    while (_esInicioInstruccion()) {
      lista.add(parseInstruccion());
    }

    if (_es(TipoToken.sen) || _es(TipoToken.cos) || _es(TipoToken.tang)) {
      final nombre = _actual.valor;
      final linea = _actual.linea;
      throw ErrorSintactico(
          '❌ Ups, en la línea $linea usaste $nombre solo, sin AVANZAR, GIRAR ni una variable.\n'
              '👉 Van dentro de una orden o variable. Ejemplo: AVANZAR SEN(30)  o  A = SEN(30)');
    }

    if (lista.isEmpty) {
      final linea = lineaApertura ?? _actual.linea;
      final siguiente = _actual.tipo;

      if (siguiente == TipoToken.fin) {
        if (lineaApertura == null) {
          throw ErrorSintactico(
              '❌ Ups, en la línea $linea tu programa está vacío.\n'
                  '👉 Entre PROGRAMA y FIN PROGRAMA escribe lo que debe hacer el robot.');
        }
        throw ErrorSintactico(
            '❌ Ups, en la línea $linea este bloque está vacío: no tiene nada adentro.\n'
                '👉 Dentro de un SI o un REPETIR va al menos una orden, como AVANZAR 10.');
      }

      if (siguiente == TipoToken.finArchivo) {
        throw ErrorSintactico(
            '❌ Ups, en la línea $linea tu programa está vacío.\n'
                '👉 Entre PROGRAMA y FIN PROGRAMA escribe lo que debe hacer el robot.');
      }

      if (!_es(TipoToken.fin)) {
        throw ErrorSintactico(
            '❌ Ups, en la línea $linea "${_actual.valor}" no es una orden que yo conozca.\n'
                '👉 Puedes usar: GIRAR, AVANZAR, SI, REPETIR, o guardar un número en una variable.');
      }
    }
    return NodoInstrucciones(lista);
  }

  Nodo parseInstruccion() {
    switch (_actual.tipo) {
      case TipoToken.identificador:
        return parseAsignacion();
      case TipoToken.girar:
        return parseGirar();
      case TipoToken.avanzar:
        return parseAvanzar();
      case TipoToken.si:
        return parseCondicional();
      case TipoToken.repetir:
        return parseCiclo();
      case TipoToken.comandoCustom:
        return parseCustom();
      default:
        throw ErrorSintactico(
            '❌ Ups, en la línea ${_actual.linea} "${_actual.valor}" no es una orden que yo conozca.\n'
                '👉 Puedes usar: GIRAR, AVANZAR, SI, REPETIR, o guardar un número en una variable.');
    }
  }

  NodoCustom parseCustom() {
    final token = _consumir(TipoToken.comandoCustom);
    NodoExpArit? arg;
    if (_es(TipoToken.numero) ||
        _es(TipoToken.identificador) ||
        _es(TipoToken.parentesisIzq) ||
        _es(TipoToken.menos) ||
        _es(TipoToken.sen) ||
        _es(TipoToken.cos) ||
        _es(TipoToken.tang)) {
      arg = _parseExpArit();
    }
    return NodoCustom(token.valor, argumento: arg);
  }

  NodoAsignacion parseAsignacion() {
    final idToken = _consumir(TipoToken.identificador);
    final id = idToken.valor;
    final linea = idToken.linea;

    if (!_es(TipoToken.asignacion)) {
      final parecida = _ordenParecida(id);
      if (parecida != null) {
        throw ErrorSintactico(
            '❌ Ups, en la línea $linea "$id" no es una orden que yo conozca.\n'
                '👉 ¿Quisiste escribir $parecida?');
      }
      throw ErrorSintactico(
          '❌ Ups, en la línea $linea escribiste "$id" solo y falta completarlo.\n'
              '👉 Para guardar un número escribe: $id = 10  (o borra esa línea)');
    }
    _consumir(TipoToken.asignacion);
    return NodoAsignacion(id, _parseExpArit());
  }

  NodoGirar parseGirar() {
    _consumir(TipoToken.girar);
    return NodoGirar(_parseExpArit());
  }

  NodoAvanzar parseAvanzar() {
    _consumir(TipoToken.avanzar);
    return NodoAvanzar(_parseExpArit());
  }

  NodoCondicional parseCondicional() {
    final lineaSI = _actual.linea;
    _consumir(TipoToken.si);
    final condicion = _parseExpBool();
    _consumir(TipoToken.entonces);
    _consumir(TipoToken.dosPuntos);
    final instrucciones = parseInstrucciones(lineaApertura: lineaSI);
    _consumir(TipoToken.fin);
    _consumir(TipoToken.si);
    return NodoCondicional(condicion, instrucciones);
  }

  NodoCiclo parseCiclo() {
    final lineaRepetir = _actual.linea;
    _consumir(TipoToken.repetir);
    _consumir(TipoToken.corcheteIzq);
    final exp = _parseExpArit();
    _consumir(TipoToken.corcheteDer);
    _consumir(TipoToken.veces);
    _consumir(TipoToken.dosPuntos);
    final instrucciones = parseInstrucciones(lineaApertura: lineaRepetir);
    _consumir(TipoToken.fin);
    _consumir(TipoToken.repetir);
    return NodoCiclo(exp, instrucciones);
  }

  NodoExpArit _parseExpArit() => _parseTermino();

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
    if (_es(TipoToken.menos)) {
      _pos++;
      return NodoNegUnaria(_parsePrimario());
    }
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
    throw ErrorSintactico(
        '❌ Línea ${_actual.linea}: Se esperaba un número, variable o función.\n'
            '👉 Por ejemplo: 10, N, o SEN(30)');
  }

  NodoExpBool _parseExpBool() => _parseOr();

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
      return NodoNot(_parseNot());
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
    if (_es(TipoToken.igual)) {
      _pos++;
      return '==';
    }
    if (_es(TipoToken.mayor)) {
      _pos++;
      return '>';
    }
    if (_es(TipoToken.menor)) {
      _pos++;
      return '<';
    }
    if (_es(TipoToken.asignacion)) {
      throw ErrorSintactico(
          '❌ Ups, en la línea ${_actual.linea} para comparar se usan dos signos igual ( == ), no uno.\n'
              '👉 Por ejemplo: SI N == 5 ENTONCES:');
    }
    throw ErrorSintactico(
        '❌ Ups, en la línea ${_actual.linea} al SI le falta el signo para comparar.\n'
            '👉 Usa < (menor que), > (mayor que) o == (igual a). Por ejemplo: SI N < 10 ENTONCES:');
  }
}
