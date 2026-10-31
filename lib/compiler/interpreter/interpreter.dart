import '../ast/nodes.dart';
import 'dart:math' as math;

class ErrorEjecucion implements Exception {
  final String mensaje;
  ErrorEjecucion(this.mensaje);
  @override
  String toString() => mensaje;
}

class Interprete {
  /// Máximo de veces que puede repetirse un solo REPETIR.
  static const int maxRepeticiones = 400;

  /// Máximo de instrucciones ejecutadas en total (cuenta también las de dentro
  /// de los REPETIR). Sin este tope, dos REPETIR anidados de 400 hacen 160.000
  /// iteraciones y tres bloquean la aplicación.
  static const int maxPasos = 10000;

  final Map<String, double> variables = {};
  final List<String> salida = [];

  /// Mensaje del error de ejecución, o null si el programa terminó bien.
  String? error;

  int _pasos = 0;

  void ejecutar(NodoPrograma programa) {
    salida.clear();
    variables.clear();
    error  = null;
    _pasos = 0;
    salida.add('▶ Iniciando programa: "${programa.nombre}"');
    try {
      _ejecutarLista(programa.instrucciones);
      salida.add('■ Programa finalizado correctamente.');
    } catch (e) {
      error = e.toString();
      salida.add(error!);
    }
  }

  void _ejecutarLista(NodoInstrucciones nodo) {
    for (final instruccion in nodo.lista) {
      _ejecutar(instruccion);
    }
  }

  double _evaluarExp(NodoExpArit exp) {
    if (exp is NodoNumero) {
      return exp.valor;
    } else if (exp is NodoVariable) {
      if (!variables.containsKey(exp.nombre)) {
        throw ErrorEjecucion(
            '❌ Ups, la variable "${exp.nombre}" todavía no tiene ningún valor.\n'
                '👉 Dale un valor antes de usarla, por ejemplo: ${exp.nombre} = 10');
      }
      return variables[exp.nombre]!;
    } else if (exp is NodoOpBinaria) {
      final izq = _evaluarExp(exp.izq);
      final der = _evaluarExp(exp.der);
      switch (exp.operador) {
        case '+': return izq + der;
        case '-': return izq - der;
        case '*': return izq * der;
        case '/':
          if (der == 0) throw ErrorEjecucion('❌ Ups, no se puede dividir entre cero.');
          return izq / der;
        case '^': return math.pow(izq, der).toDouble();
        default: return 0;
      }
    } else if (exp is NodoNegUnaria) {
      return -_evaluarExp(exp.expresion);
    } else if (exp is NodoFuncTrig) {
      final arg = _evaluarExp(exp.argumento);
      final rad = arg * math.pi / 180.0;
      switch (exp.funcion) {
        case 'SEN': return math.sin(rad);
        case 'COS': return math.cos(rad);
        case 'TANG':
          {
            final t = math.tan(rad);
            // tan(90°) no existe: en punto flotante da ~1.6e16 en vez de infinito.
            if (!t.isFinite || t.abs() > 1e9) {
              throw ErrorEjecucion(
                  '❌ Ups, TANG(${_formatear(arg)}) no existe.\n'
                      '👉 La tangente no existe en 90°, 270°... Prueba con otro ángulo, por ejemplo TANG(45).');
            }
            return t;
          }
        default: return 0;
      }
    }
    return 0;
  }

  bool _evaluarBool(NodoExpBool exp) {
    if (exp is NodoComparacion) {
      final izq = _evaluarExp(exp.izq);
      final der = _evaluarExp(exp.der);
      switch (exp.comparador) {
        case '==': return izq == der;
        case '>':  return izq > der;
        case '<':  return izq < der;
        case '>=': return izq >= der;
        case '<=': return izq <= der;
        case '!=': return izq != der;
        default: return false;
      }
    } else if (exp is NodoNot) {
      return !_evaluarBool(exp.expresion);
    } else if (exp is NodoAnd) {
      return _evaluarBool(exp.izq) && _evaluarBool(exp.der);
    } else if (exp is NodoOr) {
      return _evaluarBool(exp.izq) || _evaluarBool(exp.der);
    }
    return false;
  }

  String _formatear(double n) {
    if (n.isInfinite || n.isNaN) return n.toString();
    // Redondea a 4 decimales: elimina el ruido de punto flotante (COS(90) da
    // 6.1e-17 y SEN(30) da 0.49999999999999994) y evita la notación científica,
    // que el robot no entiende.
    final r = double.parse(n.toStringAsFixed(4));
    if (r == 0) return '0'; // también evita "-0"
    return (r == r.truncateToDouble() && r.abs() < 1e15)
        ? r.toInt().toString()
        : r.toString();
  }

  void _ejecutar(Nodo nodo) {
    if (++_pasos > maxPasos) {
      throw ErrorEjecucion(
          '❌ Ups, tu programa hace demasiadas cosas (más de $maxPasos pasos).\n'
              '👉 Revisa tus REPETIR: si pones uno dentro de otro, las vueltas se multiplican.');
    }

    if (nodo is NodoAsignacion) {
      final valor = _evaluarExp(nodo.expresion);
      variables[nodo.identificador] = valor;
      salida.add('${nodo.identificador} = ${_formatear(valor)}');

    } else if (nodo is NodoGirar) {
      final valor = _evaluarExp(nodo.expresion);
      salida.add('GIRAR ${_formatear(valor)}');

    } else if (nodo is NodoAvanzar) {
      final valor = _evaluarExp(nodo.expresion);
      salida.add('AVANZAR ${_formatear(valor)}');

    } else if (nodo is NodoCondicional) {
      if (_evaluarBool(nodo.condicion)) {
        _ejecutarLista(nodo.instrucciones);
      }

    } else if (nodo is NodoCiclo) {
      final veces = _evaluarExp(nodo.expresion).toInt();

      if (veces <= 0) return;

      if (veces > maxRepeticiones) {
        throw ErrorEjecucion(
            '❌ Ups, ese REPETIR daría $veces vueltas y el máximo es $maxRepeticiones.\n'
                '👉 Usa un número menor o igual a $maxRepeticiones en la variable del REPETIR.');
      }

      for (var i = 0; i < veces; i++) {
        _ejecutarLista(nodo.instrucciones);
      }
    } else if (nodo is NodoCustom) {
      final arg = nodo.argumento != null ? _evaluarExp(nodo.argumento!) : null;
      salida.add('${nodo.nombre}${arg != null ? ' ${_formatear(arg)}' : ''}');
    }
  }
}