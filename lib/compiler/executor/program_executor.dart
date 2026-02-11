import '../parser/ast_nodes.dart';
import '../semantic/symbol_table.dart';
import 'instruction.dart';

/// Ejecutor que convierte el AST en lista de instrucciones ejecutables
class ProgramExecutor implements ASTVisitor {
  final SymbolTable symbolTable;
  final List<Instruction> instructions = [];

  ProgramExecutor({SymbolTable? symbolTable})
      : symbolTable = symbolTable ?? SymbolTable();

  /// Ejecuta el programa y retorna las instrucciones
  List<Instruction> execute(ProgramNode program) {
    instructions.clear();
    symbolTable.clear();
    
    program.accept(this);
    return instructions;
  }

  @override
  void visitProgram(ProgramNode node) {
    for (final instruccion in node.instrucciones) {
      instruccion.accept(this);
    }
  }

  @override
  void visitAsignacion(AsignacionNode node) {
    final value = _evaluarValor(node.valor);
    symbolTable.define(node.variable, value);
    instructions.add(Instruction.asignar(node.variable, value));
  }

  @override
  void visitAvanzar(AvanzarNode node) {
    final distancia = _evaluarValor(node.distancia);
    instructions.add(Instruction.avanzar(distancia));
  }

  @override
  void visitGirar(GirarNode node) {
    final angulo = _evaluarValor(node.angulo);
    instructions.add(Instruction.girar(angulo));
  }

  @override
  void visitCondicional(CondicionalNode node) {
    final cumpleCondicion = _evaluarCondicion(node.condicion);
    
    if (cumpleCondicion) {
      for (final instruccion in node.instrucciones) {
        instruccion.accept(this);
      }
    }
  }

  @override
  void visitCiclo(CicloNode node) {
    final repeticiones = symbolTable.get(node.variable) as int;
    
    for (int i = 0; i < repeticiones; i++) {
      for (final instruccion in node.instrucciones) {
        instruccion.accept(this);
      }
    }
  }

  @override
  void visitCondicion(CondicionNode node) {
    // Las condiciones se evalúan en visitCondicional
  }

  @override
  void visitVariable(VariableNode node) {
    // Las variables se resuelven en _evaluarValor
  }

  @override
  void visitNumero(NumeroNode node) {
    // Los números se resuelven en _evaluarValor
  }

  /// Evalúa un valor (puede ser número o variable)
  int _evaluarValor(ASTNode node) {
    if (node is NumeroNode) {
      return node.valor;
    }
    
    if (node is VariableNode) {
      return symbolTable.get(node.nombre) as int;
    }
    
    throw Exception('Tipo de valor no soportado: ${node.runtimeType}');
  }

  /// Evalúa una condición
  bool _evaluarCondicion(CondicionNode condicion) {
    final valorVariable = symbolTable.get(condicion.variable) as int;
    final valorComparar = _evaluarValor(condicion.valor);
    
    switch (condicion.comparador) {
      case '==':
        return valorVariable == valorComparar;
      case '<':
        return valorVariable < valorComparar;
      case '>':
        return valorVariable > valorComparar;
      default:
        throw Exception('Comparador no soportado: ${condicion.comparador}');
    }
  }

  /// Obtiene un resumen de la ejecución
  String getSummary() {
    return 'Programa ejecutado: ${instructions.length} instrucciones generadas';
  }
}
