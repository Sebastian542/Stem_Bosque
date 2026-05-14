import '../ast/nodes.dart';
import 'dart:math' as math;

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
    salida.clear();
    variables.clear();
    salida.add('▶ Iniciando programa: "${programa.nombre}"');
    try {
      _ejecutarLista(programa.instrucciones);
      salida.add('■ Programa finalizado correctamente.');
    } catch (e) {
      salida.add(e.toString());
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
        throw ErrorEjecucion('❌ Error: La variable "${exp.nombre}" no ha sido definida.');
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
          if (der == 0) throw ErrorEjecucion('❌ Error: División por cero.');
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
        case 'TANG': return math.tan(rad);
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
    // Convertimos a 'num' para que toString() sea inteligente (quita el .0 si es entero)
    num m = n;
    if (m == m.toInt()) m = m.toInt();
    return m.toString();
  }

  void _ejecutar(Nodo nodo) {
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

      if (veces > 400) {
        throw ErrorEjecucion('❌ Error: El ciclo REPETIR tiene demasiadas repeticiones ($veces). Máximo 400.');
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
