import '../parser/ast_nodes.dart';
import 'symbol_table.dart';

/// Analizador semántico que verifica la correctitud del programa
class SemanticAnalyzer implements ASTVisitor {
  final SymbolTable symbolTable;
  final List<String> errors = [];

  SemanticAnalyzer({SymbolTable? symbolTable})
      : symbolTable = symbolTable ?? SymbolTable();

  /// Analiza el programa y retorna true si es válido
  bool analyze(ProgramNode program) {
    errors.clear();
    try {
      program.accept(this);
      return errors.isEmpty;
    } catch (e) {
      errors.add(e.toString());
      return false;
    }
  }

  @override
  void visitProgram(ProgramNode node) {
    for (final instruccion in node.instrucciones) {
      try {
        instruccion.accept(this);
      } catch (e) {
        errors.add('Error en instrucción: $e');
      }
    }
  }

  @override
  void visitAsignacion(AsignacionNode node) {
    // Evaluar el valor antes de asignar
    node.valor.accept(this);
    
    // Definir la variable en la tabla de símbolos
    // En este punto solo verificamos la sintaxis
    symbolTable.define(node.variable, 0); // Valor temporal
  }

  @override
  void visitAvanzar(AvanzarNode node) {
    node.distancia.accept(this);
  }

  @override
  void visitGirar(GirarNode node) {
    node.angulo.accept(this);
  }

  @override
  void visitCondicional(CondicionalNode node) {
    node.condicion.accept(this);
    
    for (final instruccion in node.instrucciones) {
      instruccion.accept(this);
    }
  }

  @override
  void visitCiclo(CicloNode node) {
    // Verificar que la variable del ciclo existe
    if (!symbolTable.exists(node.variable)) {
      errors.add('Variable "${node.variable}" no declarada en ciclo REPETIR');
    }
    
    for (final instruccion in node.instrucciones) {
      instruccion.accept(this);
    }
  }

  @override
  void visitCondicion(CondicionNode node) {
    // Verificar que la variable existe
    if (!symbolTable.exists(node.variable)) {
      errors.add('Variable "${node.variable}" no declarada en condición');
    }
    
    node.valor.accept(this);
  }

  @override
  void visitVariable(VariableNode node) {
    // Verificar que la variable existe cuando se usa
    if (!symbolTable.exists(node.nombre)) {
      errors.add('Variable "${node.nombre}" no declarada');
    }
  }

  @override
  void visitNumero(NumeroNode node) {
    // Los números siempre son válidos
  }

  /// Obtiene un reporte de errores
  String getErrorReport() {
    if (errors.isEmpty) {
      return 'No se encontraron errores semánticos.';
    }
    return 'Errores semánticos encontrados:\n${errors.join('\n')}';
  }
}
