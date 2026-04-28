import '../models/token.dart';
import '../ast/nodes.dart';
import 'dart:math' as math;

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
            '   PROGRAMA "Mi robot"\n'
            '   Encontré $encontradoStr en lugar del nombre.';

      case TipoToken.FIN:
      // Detectar contexto por lo que sigue
        if (encontrado.tipo == TipoToken.FIN_ARCHIVO) {
          return '❌ Línea $linea: El programa nunca se cerró.\n'
              '👉 Al final de todo tu código debes escribir:\n'
              '   FIN PROGRAMA';
        }
        return '❌ Línea $linea: Falta cerrar un bloque con FIN.\n'
            '👉 Revisa que cada SI tenga su FIN SI\n'
            '   y cada REPETIR tenga su FIN REPETIR.\n'
            '   Encontré $encontradoStr donde esperaba FIN.';

      case TipoToken.PROGRAMA when encontrado.tipo == TipoToken.FIN:
        return '❌ Línea $linea: Escribiste FIN pero falta completar con PROGRAMA.\n'
            '👉 Para cerrar el programa escribe exactamente:\n'
            '   FIN PROGRAMA';

      case TipoToken.ENTONCES:
        return '❌ Línea $linea: En el SI falta escribir ENTONCES: después de la condición.\n'
            '👉 La estructura correcta es:\n'
            '   SI ${encontrado.valor != '' ? '[variable] [comparador] [número]' : 'N < 10'} ENTONCES:\n'
            '     (instrucciones)\n'
            '   FIN SI\n'
            '   Encontré $encontradoStr donde esperaba ENTONCES.';

      case TipoToken.DOS_PUNTOS:
        if (encontrado.tipo == TipoToken.ENTONCES) {
          return '❌ Línea $linea: Escribiste ENTONCES pero falta el ":" al final.\n'
              '👉 Debe ser ENTONCES: (con dos puntos pegados).';
        }
        if (encontrado.tipo == TipoToken.VECES) {
          return '❌ Línea $linea: Escribiste VECES pero falta el ":" al final.\n'
              '👉 Debe ser VECES: (con dos puntos pegados).';
        }
        return '❌ Línea $linea: Falta el ":" al final de esta línea.\n'
            '👉 Tanto ENTONCES como VECES siempre terminan con ":".\n'
            '   Encontré $encontradoStr donde esperaba ":".';

      case TipoToken.VECES:
        return '❌ Línea $linea: Después de [${encontrado.valor}] falta escribir VECES:\n'
            '👉 La estructura correcta es:\n'
            '   REPETIR [N] VECES:\n'
            '     (instrucciones)\n'
            '   FIN REPETIR\n'
            '   Encontré $encontradoStr donde esperaba VECES.';

      case TipoToken.CORCHETE_IZQ:
        return '❌ Línea $linea: Después de REPETIR falta el "[" para encerrar la variable.\n'
            '👉 La estructura correcta es:\n'
            '   REPETIR [N] VECES:\n'
            '   El nombre de la variable va entre corchetes [ ].\n'
            '   Encontré $encontradoStr donde esperaba "[".';

      case TipoToken.CORCHETE_DER:
        return '❌ Línea $linea: Falta cerrar el corchete "]" después del nombre de la variable.\n'
            '👉 Debe ser [${encontrado.valor}] con corchete de cierre.\n'
            '   Ejemplo: REPETIR [N] VECES:';

      case TipoToken.IDENTIFICADOR:
        if (encontrado.tipo == TipoToken.NUMERO) {
          return '❌ Línea $linea: Pusiste el número ${encontrado.valor} donde debía ir el nombre de una variable.\n'
              '👉 El nombre de una variable solo puede tener letras, como N, Contador, Pasos.\n'
              '   Ejemplo correcto: REPETIR [N] VECES:';
        }
        return '❌ Línea $linea: Se esperaba el nombre de una variable pero encontré $encontradoStr.\n'
            '👉 Los nombres de variables usan solo letras y números, sin espacios ni símbolos.\n'
            '   Ejemplos válidos: N, Contador, Pasos, Vel2';

      case TipoToken.NUMERO:
        if (encontrado.tipo == TipoToken.IDENTIFICADOR) {
          return '❌ Línea $linea: Pusiste "${encontrado.valor}" donde debía ir un número.\n'
              '👉 Después de GIRAR y AVANZAR siempre va un número.\n'
              '   Ejemplo: GIRAR 90   AVANZAR 5\n'
              '   Si quieres usar una variable, primero asígnale un valor:\n'
              '   N = 90\n'
              '   GIRAR N  ← esto aún no está soportado, usa el número directo.';
        }
        if (encontrado.tipo == TipoToken.FIN_ARCHIVO) {
          return '❌ Línea $linea: La instrucción se cortó, falta el número al final.\n'
              '👉 Completa la instrucción con un número.\n'
              '   Ejemplo: GIRAR 90   AVANZAR -5';
        }
        return '❌ Línea $linea: Se esperaba un número pero encontré $encontradoStr.\n'
            '👉 Escribe un número entero, positivo o negativo.\n'
            '   Ejemplos: GIRAR 90   GIRAR -45   AVANZAR 10   AVANZAR -3';

      case TipoToken.ASIGNACION:
        return '❌ Línea $linea: Falta el "=" para asignarle un valor a la variable "${encontrado.valor}".\n'
            '👉 Para guardar un número en una variable escribe:\n'
            '   ${encontrado.valor} = 10\n'
            '   Encontré $encontradoStr donde esperaba "=".';

      case TipoToken.SI:
        return '❌ Línea $linea: Falta cerrar el bloque SI con FIN SI.\n'
            '👉 Todo bloque SI debe cerrarse así:\n'
            '   SI condición ENTONCES:\n'
            '     (instrucciones)\n'
            '   FIN SI   ← esto falta\n'
            '   Encontré $encontradoStr donde esperaba FIN SI.';

      case TipoToken.REPETIR:
        return '❌ Línea $linea: Falta cerrar el bloque REPETIR con FIN REPETIR.\n'
            '👉 Todo ciclo REPETIR debe cerrarse así:\n'
            '   REPETIR [N] VECES:\n'
            '     (instrucciones)\n'
            '   FIN REPETIR   ← esto falta\n'
            '   Encontré $encontradoStr donde esperaba FIN REPETIR.';

      case TipoToken.PARENTESIS_IZQ:
        return '❌ Línea $linea: Después del nombre de la función falta el paréntesis "(".\n'
            '👉 Las funciones matemáticas se escriben así:\n'
            '   SEN(90)   COS(45)   TANG(30)\n'
            '   Encontré $encontradoStr donde esperaba "(".';

      case TipoToken.PARENTESIS_DER:
        return '❌ Línea $linea: Falta cerrar el paréntesis ")" de la función.\n'
            '👉 Ejemplo correcto: SEN(90)  COS(45)  TANG(30)\n'
            '   Encontré $encontradoStr donde esperaba ")".';

      default:
        return '❌ Línea $linea: Error inesperado cerca de $encontradoStr.\n'
            '👉 Revisa que la instrucción esté completa y bien escrita.\n'
            '   Instrucciones válidas: PROGRAMA, GIRAR, AVANZAR, SI, REPETIR, FIN PROGRAMA.';
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
          '❌ Línea ${_actual.linea}: Hay código suelto después de FIN PROGRAMA.\n'
              '👉 FIN PROGRAMA debe ser la última línea del archivo.\n'
              '   Elimina o mueve lo que está después de FIN PROGRAMA.'
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
            '❌ Línea $linea: El bloque está vacío, no tiene ninguna instrucción.\n'
                '👉 Dentro de un SI o REPETIR debe haber al menos una instrucción.\n'
                '   Ejemplo:\n'
                '   SI N < 5 ENTONCES:\n'
                '     AVANZAR 10\n'
                '   FIN SI'
        );
      }

      if (siguiente == TipoToken.FIN_ARCHIVO) {
        throw ErrorSintactico(
            '❌ Línea $linea: El programa termina sin ninguna instrucción.\n'
                '👉 Agrega al menos un GIRAR o AVANZAR dentro del programa.\n'
                '   Ejemplo: AVANZAR 5'
        );
      }

      throw ErrorSintactico(
          '❌ Línea $linea: "${_actual.valor}" no es una instrucción válida.\n'
              '👉 Las instrucciones que puedes usar son:\n'
              '   GIRAR [número]       → gira el robot\n'
              '   AVANZAR [número]     → mueve el robot\n'
              '   SI condición ENTONCES:  → bloque condicional\n'
              '   REPETIR [N] VECES:   → ciclo\n'
              '   [variable] = [número] → guardar un valor'
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
    final num = _parseExpresionNumerica();
    return NodoGirar(num);
  }

  NodoAvanzar parseAvanzar() {
    _consumir(TipoToken.AVANZAR);
    final num = _parseExpresionNumerica();
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

    if (!_es(TipoToken.CORCHETE_IZQ)) {
      throw ErrorSintactico(
          '❌ Línea ${_actual.linea}: Después de REPETIR falta la variable entre corchetes.\n'
              '👉 Escribe el nombre de la variable entre [ ] así:\n'
              '   REPETIR [N] VECES:\n'
              '   Primero asegúrate de haber definido N = 5 antes del REPETIR.'
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
        '❌ Línea ${_actual.linea}: En el SI falta el símbolo de comparación.\n'
            '👉 Después del nombre de la variable debes poner uno de estos:\n'
            '   <  (menor que)   →  SI N < 10 ENTONCES:\n'
            '   >  (mayor que)   →  SI N > 3  ENTONCES:\n'
            '   == (igual a)     →  SI N == 5 ENTONCES:\n'
            '   Encontré "${_actual.valor}" donde esperaba <, > o =='
    );
  }

  int _parseExpresionNumerica() {
    // Caso trig: SEN(90), COS(45), TANG(30)
    if (_es(TipoToken.SEN) || _es(TipoToken.COS) || _es(TipoToken.TANG)) {
      final tipo    = _actual.tipo;
      final nombre  = _actual.valor;
      final lineaFn = _actual.linea;
      _pos++;

      if (!_es(TipoToken.PARENTESIS_IZQ)) {
        throw ErrorSintactico(
            '❌ Línea ${_actual.linea}: Después del nombre de la función falta "(".\n'
                '👉 Escribe el ángulo en grados dentro de paréntesis:\n'
                '   GIRAR SEN(90)\n'
                '   AVANZAR COS(45)'
        );
      }
      _consumir(TipoToken.PARENTESIS_IZQ);

      if (!_es(TipoToken.NUMERO)) {
        throw ErrorSintactico(
            '❌ Línea ${_actual.linea}: Dentro de la función falta el número de grados.\n'
                '👉 Escribe un número en grados dentro del paréntesis:\n'
                '   SEN(90)   COS(45)   TANG(30)'
        );
      }
      final grados  = int.parse(_consumir(TipoToken.NUMERO).valor);
      _consumir(TipoToken.PARENTESIS_DER);

      final rad = grados * math.pi / 180.0;
      double resultado;
      switch (tipo) {
        case TipoToken.SEN:  resultado = math.sin(rad); break;
        case TipoToken.COS:  resultado = math.cos(rad); break;
        case TipoToken.TANG: resultado = math.tan(rad); break;
        default:             resultado = 0;
      }
      return resultado.round();
    }

    // Caso normal: número directo
    if (!_es(TipoToken.NUMERO)) {
      throw ErrorSintactico(
          '❌ Línea ${_actual.linea}: Se esperaba un número o una función matemática.\n'
              '👉 Ejemplos válidos:\n'
              '   GIRAR 90\n'
              '   GIRAR -45\n'
              '   GIRAR SEN(90)\n'
              '   AVANZAR COS(45)'
      );
    }
    return int.parse(_consumir(TipoToken.NUMERO).valor);
  }
}