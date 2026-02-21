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
        ? 'el final del programa'
        : '"${encontrado.valor}"';

    switch (esperado) {
      case TipoToken.PROGRAMA:
        return '😕 Línea $linea: Tu programa debe comenzar con la palabra PROGRAMA.\n'
            '💡 Ejemplo: PROGRAMA "Mi robot"';
      case TipoToken.FIN:
        return '😕 Línea $linea: Falta la palabra FIN para cerrar un bloque.\n'
            '💡 Cada REPETIR y cada SI necesitan su propio FIN al terminar.';
      case TipoToken.TEXTO:
        return '😕 Línea $linea: Después de PROGRAMA debes poner el nombre entre comillas.\n'
            '💡 Ejemplo: PROGRAMA "Mi robot explorador"';
      case TipoToken.ENTONCES:
        return '😕 Línea $linea: Después de la condición del SI falta escribir ENTONCES:\n'
            '💡 Ejemplo: SI N < 10 ENTONCES:';
      case TipoToken.DOS_PUNTOS:
        return '😕 Línea $linea: Falta el símbolo ":" al final de esta línea.\n'
            '💡 El ENTONCES: y el VECES: siempre llevan dos puntos al final.';
      case TipoToken.VECES:
        return '😕 Línea $linea: Después de los corchetes falta escribir VECES:\n'
            '💡 Ejemplo: REPETIR [N] VECES:';
      case TipoToken.CORCHETE_IZQ:
        return '😕 Línea $linea: Falta el corchete "[" antes del nombre de la variable.\n'
            '💡 Ejemplo: REPETIR [N] VECES:';
      case TipoToken.CORCHETE_DER:
        return '😕 Línea $linea: Falta el corchete "]" después del nombre de la variable.\n'
            '💡 Ejemplo: REPETIR [N] VECES:';
      case TipoToken.IDENTIFICADOR:
        return '😕 Línea $linea: Aquí se esperaba el nombre de una variable pero encontré $encontradoStr.\n'
            '💡 Los nombres de variables solo pueden tener letras y números, sin espacios.';
      case TipoToken.NUMERO:
        return '😕 Línea $linea: Aquí se necesita un número pero encontré $encontradoStr.\n'
            '💡 Ejemplo: GIRAR 90  o  AVANZAR -5';
      case TipoToken.ASIGNACION:
        return '😕 Línea $linea: Falta el signo "=" para darle un valor a la variable.\n'
            '💡 Ejemplo: N = 10';
      case TipoToken.SI:
        return '😕 Línea $linea: Falta cerrar el bloque con FIN SI.\n'
            '💡 Recuerda escribir FIN SI al terminar el bloque condicional.';
      case TipoToken.REPETIR:
        return '😕 Línea $linea: Falta cerrar el bloque con FIN REPETIR.\n'
            '💡 Recuerda escribir FIN REPETIR al terminar el ciclo.';
      default:
        return '😕 Línea $linea: Algo no está bien cerca de $encontradoStr.\n'
            '💡 Revisa que las palabras estén bien escritas y en el orden correcto.';
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

  NodoPrograma parsePrograma() {
    _consumir(TipoToken.PROGRAMA);
    final nombre = _consumir(TipoToken.TEXTO).valor;
    final instrucciones = parseInstrucciones();
    _consumir(TipoToken.FIN);
    _consumir(TipoToken.PROGRAMA);
    if (!_es(TipoToken.FIN_ARCHIVO)) {
      throw ErrorSintactico(
          '😕 Línea ${_actual.linea}: Hay código después de FIN PROGRAMA.\n'
              '💡 FIN PROGRAMA debe ser lo último que escribas.'
      );
    }
    return NodoPrograma(nombre, instrucciones);
  }

  NodoInstrucciones parseInstrucciones() {
    final lista = <Nodo>[];
    while (_esInicioInstruccion()) {
      lista.add(parseInstruccion());
    }
    if (lista.isEmpty) {
      final linea     = _actual.linea;
      final siguiente = _actual.tipo;

      if (siguiente == TipoToken.FIN) {
        throw ErrorSintactico(
            '😕 Línea $linea: ¡Este bloque está vacío!\n'
                '💡 Dentro de un SI o REPETIR debes poner al menos una instrucción.\n'
                '   Ejemplo:\n'
                '   SI N < 2 ENTONCES:\n'
                '     AVANZAR 5\n'
                '   FIN SI'
        );
      }

      if (siguiente == TipoToken.FIN_ARCHIVO) {
        throw ErrorSintactico(
            '😕 Línea $linea: El programa termina de repente sin instrucciones.\n'
                '💡 Agrega al menos un GIRAR o AVANZAR dentro del programa.'
        );
      }

      throw ErrorSintactico(
          '😕 Línea $linea: Aquí se esperaba una instrucción pero encontré "${_actual.valor}".\n'
              '💡 Las instrucciones válidas son: GIRAR, AVANZAR, SI, REPETIR, o una variable.'
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
            '😕 Línea ${_actual.linea}: No reconozco la instrucción "${_actual.valor}".\n'
                '💡 Las instrucciones válidas son: GIRAR, AVANZAR, SI, REPETIR, o el nombre de una variable.'
        );
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

    // ANTES: [N] era opcional, permitía REPETIR VECES: sin variable
    // AHORA: [N] es obligatorio
    if (!_es(TipoToken.CORCHETE_IZQ)) {
      throw ErrorSintactico(
          '😕 Línea ${_actual.linea}: Después de REPETIR debes poner la variable entre corchetes.\n'
              '💡 Ejemplo: REPETIR [N] VECES:'
      );
    }
    _consumir(TipoToken.CORCHETE_IZQ);
    final identificador = _consumir(TipoToken.IDENTIFICADOR).valor;
    _consumir(TipoToken.CORCHETE_DER);
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
        '😕 Línea ${_actual.linea}: Aquí necesito un comparador pero encontré "${_actual.valor}".\n'
            '💡 Los comparadores válidos son:  ==  (igual),  >  (mayor que),  <  (menor que)\n'
            '   Ejemplo: SI N < 10 ENTONCES:'
    );
  }
}