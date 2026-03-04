import '../ast/nodes.dart';

class GeneradorCodigo {
  final StringBuffer _buf = StringBuffer();
  final Set<String> _variables = {};
  int _sangria = 0;

  // ============================
  // MÉTODO PRINCIPAL
  // ============================

  String generar(NodoPrograma programa) {
    _buf.clear();
    _variables.clear();

    _recolectarVariables(programa.instrucciones);

    _escribir('// Código Dart generado automáticamente');
    _escribir('// Programa: "${_escapar(programa.nombre)}"');
    _escribir('');
    _escribir('import "dart:math";');
    _escribir('');
    _escribir('void girar(double g) => print("🔄 Girar \$g°");');
    _escribir('void avanzar(double p) => print("➡ Avanzar \$p unidades");');
    _escribir('');
    _escribir('void main() {');
    _sangria++;

    _escribir('print("▶ Programa: ${_escapar(programa.nombre)}");');
    _escribir('');

    // Declarar variables
    for (final v in _variables) {
      _escribir('double $v = 0;');
    }

    if (_variables.isNotEmpty) {
      _escribir('');
    }

    _generarLista(programa.instrucciones);

    _escribir('');
    _escribir('print("■ Fin del programa.");');

    _sangria--;
    _escribir('}');

    return _buf.toString();
  }

  // ============================
  // RECOLECCIÓN DE VARIABLES
  // ============================

  void _recolectarVariables(NodoInstrucciones nodo) {
    for (final n in nodo.lista) {
      if (n is NodoAsignacion) {
        _variables.add(n.identificador);
      }
      else if (n is NodoCondicional) {
        _recolectarVariables(n.instrucciones);
      }
      else if (n is NodoCiclo) {
        _recolectarVariables(n.instrucciones);
      }
    }
  }

  // ============================
  // GENERACIÓN DE INSTRUCCIONES
  // ============================

  void _generarLista(NodoInstrucciones nodo) {
    for (final n in nodo.lista) {
      _generarNodo(n);
    }
  }

  void _generarNodo(Nodo nodo) {

    if (nodo is NodoAsignacion) {
      final expr = _genExpArit(nodo.expresion);
      _escribir('${nodo.identificador} = $expr;');
    }

    else if (nodo is NodoGirar) {
      final expr = _genExpArit(nodo.expresion);
      _escribir('girar($expr);');
    }

    else if (nodo is NodoAvanzar) {
      final expr = _genExpArit(nodo.expresion);
      _escribir('avanzar($expr);');
    }

    else if (nodo is NodoCondicional) {
      final cond = _genExpBool(nodo.condicion);
      _escribir('if ($cond) {');
      _sangria++;
      _generarLista(nodo.instrucciones);
      _sangria--;
      _escribir('}');
    }

    else if (nodo is NodoCiclo) {
      final limite = _genExpArit(nodo.expresion);
      _escribir('for (int _i = 0; _i < $limite; _i++) {');
      _sangria++;
      _generarLista(nodo.instrucciones);
      _sangria--;
      _escribir('}');
    }
  }

  // ============================
  // GENERACIÓN EXPRESIONES ARITMÉTICAS
  // ============================

  String _genExpArit(NodoExpArit nodo) {

    if (nodo is NodoNumero) {
      return nodo.valor.toString();
    }

    if (nodo is NodoVariable) {
      return nodo.nombre;
    }

    if (nodo is NodoOpBinaria) {
      final izq = _genExpArit(nodo.izq);
      final der = _genExpArit(nodo.der);
      return '($izq ${nodo.operador} $der)';
    }

    if (nodo is NodoNegUnaria) {
      final exp = _genExpArit(nodo.expresion);
      return '-($exp)';
    }

    if (nodo is NodoFuncTrig) {
      final arg = _genExpArit(nodo.argumento);

      switch (nodo.funcion.toUpperCase()) {
        case 'SEN':
          return 'sin($arg)';
        case 'COS':
          return 'cos($arg)';
        case 'TANG':
          return 'tan($arg)';
        default:
          throw Exception('Función trigonométrica desconocida');
      }
    }

    throw Exception('Expresión aritmética no soportada');
  }

  // ============================
  // GENERACIÓN EXPRESIONES BOOLEANAS
  // ============================

  String _genExpBool(NodoExpBool nodo) {

    if (nodo is NodoComparacion) {
      final izq = _genExpArit(nodo.izq);
      final der = _genExpArit(nodo.der);
      return '($izq ${nodo.comparador} $der)';
    }

    if (nodo is NodoNot) {
      final exp = _genExpBool(nodo.expresion);
      return '!($exp)';
    }

    if (nodo is NodoAnd) {
      final izq = _genExpBool(nodo.izq);
      final der = _genExpBool(nodo.der);
      return '($izq && $der)';
    }

    if (nodo is NodoOr) {
      final izq = _genExpBool(nodo.izq);
      final der = _genExpBool(nodo.der);
      return '($izq || $der)';
    }

    throw Exception('Expresión booleana no soportada');
  }

  // ============================
  // UTILIDADES
  // ============================

  void _escribir(String linea) {
    _buf.writeln('${'  ' * _sangria}$linea');
  }

  String _escapar(String texto) {
    return texto.replaceAll('"', '\\"');
  }
}