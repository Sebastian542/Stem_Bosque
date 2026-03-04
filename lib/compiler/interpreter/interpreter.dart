import 'dart:math' as math;
import '../ast/nodes.dart';

class ErrorEjecucion implements Exception {
  final String mensaje;
  ErrorEjecucion(this.mensaje);
  @override
  String toString() => mensaje;
}

class Interprete {
  final Map<String, double> variables = {};
  final List<String> salida = [];

  void ejecutar(NodoPrograma programa) {
    salida.add('▶ Iniciando programa: "${programa.nombre}"');
    _ejecutarLista(programa.instrucciones);
    salida.add('■ Programa finalizado correctamente.');
  }

  void _ejecutarLista(NodoInstrucciones nodo) {
    for (final instruccion in nodo.lista) {
      _ejecutar(instruccion);
    }
  }

  void _ejecutar(Nodo nodo) {
    if (nodo is NodoAsignacion) {
      final val = _evalArit(nodo.expresion);
      variables[nodo.identificador] = val;
      salida.add('${nodo.identificador} = ${_fmt(val)}');

    } else if (nodo is NodoGirar) {
      final val = _evalArit(nodo.expresion).round();
      salida.add('GIRAR $val');

    } else if (nodo is NodoAvanzar) {
      final val = _evalArit(nodo.expresion).round();
      salida.add('AVANZAR $val');

    } else if (nodo is NodoCondicional) {
      if (_evalBool(nodo.condicion)) _ejecutarLista(nodo.instrucciones);

    } else if (nodo is NodoCiclo) {
      final veces = _evalArit(nodo.expresion).round();
      if (veces <= 0) {
        throw ErrorEjecucion(
            '😕 La expresión del REPETIR dio $veces, pero necesitas un número mayor a 0.\n'
                '💡 Revisa el valor de tus variables.'
        );
      }
      if (veces > 10000) {
        throw ErrorEjecucion(
            '😕 La expresión del REPETIR dio $veces. ¡Eso es demasiado!\n'
                '💡 Usa un número menor a 10,000.'
        );
      }
      for (var i = 0; i < veces; i++) {
        _ejecutarLista(nodo.instrucciones);
      }
    }
  }

  // ── Evaluación aritmética ─────────────────────────────────────

  double _evalArit(NodoExpArit exp) {
    if (exp is NodoNumero) return exp.valor;

    if (exp is NodoVariable) {
      if (!variables.containsKey(exp.nombre)) {
        throw ErrorEjecucion(
            '😕 La variable "${exp.nombre}" no tiene valor.\n'
                '💡 Escribe: ${exp.nombre} = 10  antes de usarla.'
        );
      }
      return variables[exp.nombre]!;
    }

    if (exp is NodoNegUnaria) return -_evalArit(exp.expresion);

    if (exp is NodoFuncTrig) {
      final arg = _evalArit(exp.argumento);
      final rad = arg * math.pi / 180;
      switch (exp.funcion) {
        case 'SEN':  return math.sin(rad);
        case 'COS':  return math.cos(rad);
        case 'TANG':
          if ((arg % 180) == 90) {
            throw ErrorEjecucion(
                '😕 TANG de ${arg.round()}° no está definida (división entre cero).\n'
                    '💡 Usa un ángulo diferente a 90°, 270°, etc.'
            );
          }
          return math.tan(rad);
        default:
          throw ErrorEjecucion('😕 Función trigonométrica desconocida: ${exp.funcion}');
      }
      // ← BUG CORREGIDO: cada case ya tiene return, el default lanza excepción
    }

    if (exp is NodoOpBinaria) {
      final izq = _evalArit(exp.izq);
      final der = _evalArit(exp.der);
      switch (exp.operador) {
        case '+': return izq + der;
        case '-': return izq - der;
        case '*': return izq * der;
        case '/':
          if (der == 0) throw ErrorEjecucion('😕 División entre cero.\n💡 Revisa el divisor.');
          return izq / der;
        case '%':
          if (der == 0) throw ErrorEjecucion('😕 Módulo entre cero.\n💡 Revisa el divisor.');
          return izq % der;
        case '^': return math.pow(izq, der).toDouble();
        default:
          throw ErrorEjecucion('😕 Operador desconocido: ${exp.operador}');
      }
      // ← BUG CORREGIDO: default lanza excepción, Dart sabe que no hay camino sin return
    }

    throw ErrorEjecucion('😕 Expresión aritmética desconocida: ${exp.runtimeType}');
    // ← BUG CORREGIDO: antes terminaba con 'return 0' tras los if, ahora lanza error
  }

  // ── Evaluación booleana ───────────────────────────────────────

  bool _evalBool(NodoExpBool exp) {
    if (exp is NodoComparacion) {
      final izq = _evalArit(exp.izq);
      final der = _evalArit(exp.der);
      switch (exp.comparador) {
        case '==': return izq == der;
        case '>':  return izq > der;
        case '<':  return izq < der;
        default:
          throw ErrorEjecucion('😕 Comparador desconocido: ${exp.comparador}');
      // ← BUG CORREGIDO: antes el switch no tenía return/default al final
      }
    }
    if (exp is NodoNot) return !_evalBool(exp.expresion);
    if (exp is NodoAnd) return _evalBool(exp.izq) && _evalBool(exp.der);
    if (exp is NodoOr)  return _evalBool(exp.izq) || _evalBool(exp.der);

    throw ErrorEjecucion('😕 Expresión booleana desconocida: ${exp.runtimeType}');
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(4);
}
