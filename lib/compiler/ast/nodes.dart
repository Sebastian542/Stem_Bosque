// ── Nodo base ────────────────────────────────────────────────
abstract class Nodo {
  String mostrar(String sangria);
}

// ── Nodos concretos ──────────────────────────────────────────
class NodoPrograma extends Nodo {
  final String nombre;
  final NodoInstrucciones instrucciones;
  NodoPrograma(this.nombre, this.instrucciones);

  @override
  String mostrar(String s) =>
      '${s}Programa: "$nombre"\n${instrucciones.mostrar('$s  ')}';
}

class NodoInstrucciones extends Nodo {
  final List<Nodo> lista;
  NodoInstrucciones(this.lista);

  @override
  String mostrar(String s) => lista.map((n) => n.mostrar(s)).join('\n');
}

class NodoAsignacion extends Nodo {
  final String identificador;
  final int numero;
  NodoAsignacion(this.identificador, this.numero);

  @override
  String mostrar(String s) => '${s}Asignacion: $identificador = $numero';
}

class NodoGirar extends Nodo {
  final int numero;
  NodoGirar(this.numero);

  @override
  String mostrar(String s) => '${s}Girar: $numero grados';
}

class NodoAvanzar extends Nodo {
  final int numero;
  NodoAvanzar(this.numero);

  @override
  String mostrar(String s) => '${s}Avanzar: $numero unidades';
}

class NodoCondicion extends Nodo {
  final String identificador;
  final String comparador;
  final int numero;
  NodoCondicion(this.identificador, this.comparador, this.numero);

  @override
  String mostrar(String s) =>
      '${s}Condicion: $identificador $comparador $numero';
}

class NodoCondicional extends Nodo {
  final NodoCondicion condicion;
  final NodoInstrucciones instrucciones;
  NodoCondicional(this.condicion, this.instrucciones);

  @override
  String mostrar(String s) =>
      '${s}Si:\n${condicion.mostrar('$s  ')}\n'
          '${s}Entonces:\n${instrucciones.mostrar('$s  ')}';
}

class NodoCiclo extends Nodo {
  final String? identificador;
  final NodoInstrucciones instrucciones;
  NodoCiclo(this.identificador, this.instrucciones);

  @override
  String mostrar(String s) =>
      '${s}Repetir [${identificador ?? 'sin variable'}] veces:\n'
          '${instrucciones.mostrar('$s  ')}';
}