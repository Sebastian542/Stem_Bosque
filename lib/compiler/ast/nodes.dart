// ── Nodo base ────────────────────────────────────────────────
abstract class Nodo {
  String mostrar(String sangria);
}

// ── Nodos de expresión aritmética ────────────────────────────

abstract class NodoExpArit extends Nodo {}

/// Número literal: 5
class NodoNumero extends NodoExpArit {
  final double valor;
  NodoNumero(this.valor);
  @override
  String mostrar(String s) => '${s}Numero: $valor';
}

/// Variable: N
class NodoVariable extends NodoExpArit {
  final String nombre;
  NodoVariable(this.nombre);
  @override
  String mostrar(String s) => '${s}Variable: $nombre';
}

/// Operación binaria: izq + der
class NodoOpBinaria extends NodoExpArit {
  final NodoExpArit izq, der;
  final String operador;
  NodoOpBinaria(this.izq, this.operador, this.der);
  @override
  String mostrar(String s) =>
      '${s}OpBinaria($operador):\n${izq.mostrar('$s  ')}\n${der.mostrar('$s  ')}';
}

/// Negación unaria: -N
class NodoNegUnaria extends NodoExpArit {
  final NodoExpArit expresion;
  NodoNegUnaria(this.expresion);
  @override
  String mostrar(String s) => '${s}NegUnaria:\n${expresion.mostrar('$s  ')}';
}

/// Función trigonométrica: SEN / COS / TANG
class NodoFuncTrig extends NodoExpArit {
  final String funcion;
  final NodoExpArit argumento;
  NodoFuncTrig(this.funcion, this.argumento);
  @override
  String mostrar(String s) =>
      '${s}FuncTrig($funcion):\n${argumento.mostrar('$s  ')}';
}

// ── Nodos de expresión booleana ──────────────────────────────

abstract class NodoExpBool extends Nodo {}

/// Comparación: expr < expr
class NodoComparacion extends NodoExpBool {
  final NodoExpArit izq;
  final String comparador;
  final NodoExpArit der;
  NodoComparacion(this.izq, this.comparador, this.der);
  @override
  String mostrar(String s) =>
      '${s}Comparacion($comparador):\n${izq.mostrar('$s  ')}\n${der.mostrar('$s  ')}';
}

/// NOT <expresión>
class NodoNot extends NodoExpBool {
  final NodoExpBool expresion;
  NodoNot(this.expresion);
  @override
  String mostrar(String s) => '${s}NOT:\n${expresion.mostrar('$s  ')}';
}

/// <izq> AND <der>
class NodoAnd extends NodoExpBool {
  final NodoExpBool izq, der;
  NodoAnd(this.izq, this.der);
  @override
  String mostrar(String s) =>
      '${s}AND:\n${izq.mostrar('$s  ')}\n${der.mostrar('$s  ')}';
}

/// <izq> OR <der>
class NodoOr extends NodoExpBool {
  final NodoExpBool izq, der;
  NodoOr(this.izq, this.der);
  @override
  String mostrar(String s) =>
      '${s}OR:\n${izq.mostrar('$s  ')}\n${der.mostrar('$s  ')}';
}

// ── Nodos de instrucción ─────────────────────────────────────

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
  final NodoExpArit expresion;
  NodoAsignacion(this.identificador, this.expresion);
  @override
  String mostrar(String s) =>
      '${s}Asignacion: $identificador =\n${expresion.mostrar('$s  ')}';
}

class NodoGirar extends Nodo {
  final NodoExpArit expresion;
  NodoGirar(this.expresion);
  @override
  String mostrar(String s) => '${s}Girar:\n${expresion.mostrar('$s  ')}';
}

class NodoAvanzar extends Nodo {
  final NodoExpArit expresion;
  NodoAvanzar(this.expresion);
  @override
  String mostrar(String s) => '${s}Avanzar:\n${expresion.mostrar('$s  ')}';
}

class NodoCondicional extends Nodo {
  final NodoExpBool condicion;
  final NodoInstrucciones instrucciones;
  NodoCondicional(this.condicion, this.instrucciones);
  @override
  String mostrar(String s) =>
      '${s}Si:\n${condicion.mostrar('$s  ')}\n'
          '${s}Entonces:\n${instrucciones.mostrar('$s  ')}';
}

class NodoCiclo extends Nodo {
  final NodoExpArit expresion;
  final NodoInstrucciones instrucciones;
  NodoCiclo(this.expresion, this.instrucciones);
  @override
  String mostrar(String s) =>
      '${s}Repetir:\n${expresion.mostrar('$s  ')}\n'
          '${instrucciones.mostrar('$s  ')}';
}