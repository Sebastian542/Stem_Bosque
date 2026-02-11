/// Tabla de símbolos para almacenar variables y sus valores
class SymbolTable {
  final SymbolTable? parent;
  final Map<String, dynamic> _symbols = {};

  SymbolTable({this.parent});

  /// Agrega una nueva variable a la tabla
  void define(String name, dynamic value) {
    _symbols[name] = value;
  }

  /// Asigna un valor a una variable existente
  void assign(String name, dynamic value) {
    if (_symbols.containsKey(name)) {
      _symbols[name] = value;
    } else if (parent != null) {
      parent!.assign(name, value);
    } else {
      throw Exception('Variable "$name" no declarada');
    }
  }

  /// Obtiene el valor de una variable
  dynamic get(String name) {
    if (_symbols.containsKey(name)) {
      return _symbols[name];
    }
    
    if (parent != null) {
      return parent!.get(name);
    }
    
    throw Exception('Variable "$name" no está definida');
  }

  /// Verifica si una variable existe
  bool exists(String name) {
    if (_symbols.containsKey(name)) {
      return true;
    }
    
    if (parent != null) {
      return parent!.exists(name);
    }
    
    return false;
  }

  /// Crea una tabla hija (para ámbitos anidados)
  SymbolTable createChild() {
    return SymbolTable(parent: this);
  }

  /// Limpia todos los símbolos
  void clear() {
    _symbols.clear();
  }

  /// Obtiene todos los símbolos actuales
  Map<String, dynamic> get symbols => Map.unmodifiable(_symbols);

  @override
  String toString() {
    return 'SymbolTable($_symbols)';
  }
}
