import '../ast/nodes.dart';

class Interprete {
  final Map<String, int> variables = {};
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
      variables[nodo.identificador] = nodo.numero;
      salida.add('${nodo.identificador} = ${nodo.numero}');

    } else if (nodo is NodoGirar) {
      salida.add('GIRAR ${nodo.numero}');

    } else if (nodo is NodoAvanzar) {
      salida.add('AVANZAR ${nodo.numero}');

    } else if (nodo is NodoCondicional) {
      final c      = nodo.condicion;
      final valVar = variables[c.identificador] ?? 0;
      final ok     = _evaluar(valVar, c.comparador, c.numero);
      if (ok) _ejecutarLista(nodo.instrucciones);

    } else if (nodo is NodoCiclo) {
      final veces = nodo.identificador != null
          ? (variables[nodo.identificador!] ?? 0)
          : 1;
      for (var i = 0; i < veces; i++) {
        _ejecutarLista(nodo.instrucciones);
      }
    }
  }

  bool _evaluar(int a, String op, int b) {
    switch (op) {
      case '==': return a == b;
      case '>':  return a > b;
      case '<':  return a < b;
      default:   return false;
    }
  }
}