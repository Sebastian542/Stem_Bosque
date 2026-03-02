import '../ast/nodes.dart';

class GeneradorCodigo {
  final StringBuffer _buf = StringBuffer();
  int _sangria = 0;

  String generar(NodoPrograma programa) {
    _escribir('// Código Dart generado automáticamente');
    _escribir('// Programa: "${programa.nombre}"');
    _escribir('');
    _escribir('void girar(int g)   => print("🔄 Girar \$g°");');
    _escribir('void avanzar(int p) => print("➡ Avanzar \$p unidades");');
    _escribir('');
    _escribir('void main() {');
    _sangria++;
    _escribir('print("▶ Programa: ${programa.nombre}");');
    _escribir('');
    _generarLista(programa.instrucciones);
    _escribir('');
    _escribir('print("■ Fin del programa.");');
    _sangria--;
    _escribir('}');
    return _buf.toString();
  }

  void _generarLista(NodoInstrucciones nodo) {
    for (final i in nodo.lista) _generarNodo(i);
  }

  void _generarNodo(Nodo nodo) {
    if (nodo is NodoAsignacion) {
      _escribir('var ${nodo.identificador} = ${nodo.numero};');
    } else if (nodo is NodoGirar) {
      _escribir('girar(${nodo.numero});');
    } else if (nodo is NodoAvanzar) {
      _escribir('avanzar(${nodo.numero});');
    } else if (nodo is NodoCondicional) {
      final c = nodo.condicion;
      _escribir('if (${c.identificador} ${c.comparador} ${c.numero}) {');
      _sangria++;
      _generarLista(nodo.instrucciones);
      _sangria--;
      _escribir('}');
    } else if (nodo is NodoCiclo) {
      final v = nodo.identificador ?? '1';
      _escribir('for (var _i = 0; _i < $v; _i++) {');
      _sangria++;
      _generarLista(nodo.instrucciones);
      _sangria--;
      _escribir('}');
    }
  }

  void _escribir(String linea) => _buf.writeln('${'  ' * _sangria}$linea');
}