import '../ast/nodes.dart';

class ErrorEjecucion implements Exception {
  final String mensaje;
  ErrorEjecucion(this.mensaje);
  @override
  String toString() => mensaje;
}

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
      final c = nodo.condicion;

      // ANTES: variables[c.identificador] ?? 0  → usaba 0 si no existía
      // AHORA: lanza error si la variable no fue declarada
      if (!variables.containsKey(c.identificador)) {
        throw ErrorEjecucion(
            '😕 Estás usando la variable "${c.identificador}" en un SI, '
                'pero nunca le diste un valor.\n'
                '💡 Antes del SI, escribe: ${c.identificador} = 10\n'
                '   (o el número que quieras)'
        );
      }

      final valVar = variables[c.identificador]!;
      final ok     = _evaluar(valVar, c.comparador, c.numero);
      if (ok) _ejecutarLista(nodo.instrucciones);

    } else if (nodo is NodoCiclo) {

      // ANTES: variables[nodo.identificador!] ?? 0  → usaba 0 si no existía
      // AHORA: lanza error si la variable no fue declarada
      if (nodo.identificador != null &&
          !variables.containsKey(nodo.identificador!)) {
        throw ErrorEjecucion(
            '😕 Estás usando la variable "${nodo.identificador}" en un REPETIR, '
                'pero nunca le diste un valor.\n'
                '💡 Antes del REPETIR, escribe: ${nodo.identificador} = 5\n'
                '   (o el número de veces que quieras repetir)'
        );
      }

      final veces = nodo.identificador != null
          ? variables[nodo.identificador!]!
          : 1;

      // NUEVO: evitar ciclos infinitos o negativos
      if (veces <= 0) {
        throw ErrorEjecucion(
            '😕 La variable "${nodo.identificador}" vale $veces, '
                'pero para REPETIR necesitas un número mayor a 0.\n'
                '💡 Cambia el valor: ${nodo.identificador} = 5'
        );
      }

      // NUEVO: evitar que un niño ponga N=99999 y cuelgue la app
      if (veces > 10000) {
        throw ErrorEjecucion(
            '😕 La variable "${nodo.identificador}" vale $veces. '
                '¡Eso es demasiadas repeticiones!\n'
                '💡 Usa un número menor a 10,000.'
        );
      }

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