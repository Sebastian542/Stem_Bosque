/// Clase base para todos los nodos del AST
abstract class ASTNode {
  void accept(ASTVisitor visitor);
}

/// Visitor pattern para recorrer el AST
abstract class ASTVisitor {
  void visitProgram(ProgramNode node);
  void visitAsignacion(AsignacionNode node);
  void visitAvanzar(AvanzarNode node);
  void visitGirar(GirarNode node);
  void visitCondicional(CondicionalNode node);
  void visitCiclo(CicloNode node);
  void visitCondicion(CondicionNode node);
  void visitVariable(VariableNode node);
  void visitNumero(NumeroNode node);
}

/// Nodo raíz del programa
class ProgramNode extends ASTNode {
  final String nombre;
  final List<ASTNode> instrucciones;

  ProgramNode({
    required this.nombre,
    required this.instrucciones,
  });

  @override
  void accept(ASTVisitor visitor) => visitor.visitProgram(this);

  @override
  String toString() => 'Program($nombre, ${instrucciones.length} instrucciones)';
}

/// Nodo de asignación: variable = valor
class AsignacionNode extends ASTNode {
  final String variable;
  final ASTNode valor;

  AsignacionNode({
    required this.variable,
    required this.valor,
  });

  @override
  void accept(ASTVisitor visitor) => visitor.visitAsignacion(this);

  @override
  String toString() => 'Asignacion($variable = $valor)';
}

/// Nodo de comando AVANZAR
class AvanzarNode extends ASTNode {
  final ASTNode distancia;

  AvanzarNode({required this.distancia});

  @override
  void accept(ASTVisitor visitor) => visitor.visitAvanzar(this);

  @override
  String toString() => 'Avanzar($distancia)';
}

/// Nodo de comando GIRAR
class GirarNode extends ASTNode {
  final ASTNode angulo;

  GirarNode({required this.angulo});

  @override
  void accept(ASTVisitor visitor) => visitor.visitGirar(this);

  @override
  String toString() => 'Girar($angulo)';
}

/// Nodo condicional: SI condicion ENTONCES instrucciones FIN SI
class CondicionalNode extends ASTNode {
  final CondicionNode condicion;
  final List<ASTNode> instrucciones;

  CondicionalNode({
    required this.condicion,
    required this.instrucciones,
  });

  @override
  void accept(ASTVisitor visitor) => visitor.visitCondicional(this);

  @override
  String toString() => 'Condicional($condicion)';
}

/// Nodo de ciclo: REPETIR [variable] VECES instrucciones FIN REPETIR
class CicloNode extends ASTNode {
  final String variable;
  final List<ASTNode> instrucciones;

  CicloNode({
    required this.variable,
    required this.instrucciones,
  });

  @override
  void accept(ASTVisitor visitor) => visitor.visitCiclo(this);

  @override
  String toString() => 'Ciclo($variable veces)';
}

/// Nodo de condición: variable comparador valor
class CondicionNode extends ASTNode {
  final String variable;
  final String comparador; // ==, <, >
  final ASTNode valor;

  CondicionNode({
    required this.variable,
    required this.comparador,
    required this.valor,
  });

  @override
  void accept(ASTVisitor visitor) => visitor.visitCondicion(this);

  @override
  String toString() => 'Condicion($variable $comparador $valor)';
}

/// Nodo de variable (identificador)
class VariableNode extends ASTNode {
  final String nombre;

  VariableNode({required this.nombre});

  @override
  void accept(ASTVisitor visitor) => visitor.visitVariable(this);

  @override
  String toString() => 'Variable($nombre)';
}

/// Nodo de número literal
class NumeroNode extends ASTNode {
  final int valor;

  NumeroNode({required this.valor});

  @override
  void accept(ASTVisitor visitor) => visitor.visitNumero(this);

  @override
  String toString() => 'Numero($valor)';
}
