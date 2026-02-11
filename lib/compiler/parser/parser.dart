import '../lexer/token.dart';
import '../lexer/token_type.dart';
import 'ast_nodes.dart';

/// Analizador sintáctico que construye el AST
class Parser {
  final List<Token> tokens;
  int _current = 0;

  Parser(this.tokens);

  /// Parsea el programa completo
  ProgramNode parse() {
    try {
      return _programa();
    } catch (e) {
      throw Exception('Error de sintaxis: $e');
    }
  }

  // Programa = "PROGRAMA" cadena Instrucciones "FIN" "PROGRAMA"
  ProgramNode _programa() {
    _consume(TokenType.programa, 'Se esperaba PROGRAMA');
    
    final nombreToken = _consume(TokenType.cadena, 'Se esperaba nombre del programa');
    final nombre = nombreToken.literal as String;
    
    final instrucciones = _instrucciones();
    
    _consume(TokenType.fin, 'Se esperaba FIN');
    _consume(TokenType.programa, 'Se esperaba PROGRAMA');
    
    return ProgramNode(nombre: nombre, instrucciones: instrucciones);
  }

  // Instrucciones = Instruccion+
  List<ASTNode> _instrucciones() {
    final instrucciones = <ASTNode>[];
    
    while (!_check(TokenType.fin) && !_isAtEnd()) {
      try {
        final inst = _instruccion();
        if (inst != null) {
          instrucciones.add(inst);
        }
      } catch (e) {
        // Ignorar tokens inválidos y continuar
        if (!_isAtEnd()) _advance();
      }
    }
    
    return instrucciones;
  }

  // Instruccion = Asignacion | Accion | Ciclo | Condicional
  ASTNode? _instruccion() {
    if (_check(TokenType.identificador) && _checkNext(TokenType.igual)) {
      return _asignacion();
    }
    
    if (_check(TokenType.avanzar)) {
      return _avanzar();
    }
    
    if (_check(TokenType.girar)) {
      return _girar();
    }
    
    if (_check(TokenType.repetir)) {
      return _ciclo();
    }
    
    if (_check(TokenType.si)) {
      return _condicional();
    }
    
    return null;
  }

  // Asignacion = Variable "=" Valor
  AsignacionNode _asignacion() {
    final variable = _consume(TokenType.identificador, 'Se esperaba nombre de variable');
    _consume(TokenType.igual, 'Se esperaba =');
    final valor = _valor();
    
    return AsignacionNode(
      variable: variable.lexeme,
      valor: valor,
    );
  }

  // Avanzar = "AVANZAR" Valor
  AvanzarNode _avanzar() {
    _consume(TokenType.avanzar, 'Se esperaba AVANZAR');
    final distancia = _valor();
    
    return AvanzarNode(distancia: distancia);
  }

  // Girar = "GIRAR" Valor
  GirarNode _girar() {
    _consume(TokenType.girar, 'Se esperaba GIRAR');
    final angulo = _valor();
    
    return GirarNode(angulo: angulo);
  }

  // Condicional = "SI" Condicion "ENTONCES" ":" Instrucciones "FIN" "SI"
  CondicionalNode _condicional() {
    _consume(TokenType.si, 'Se esperaba SI');
    final condicion = _condicion();
    _consume(TokenType.entonces, 'Se esperaba ENTONCES');
    _consume(TokenType.dobleComa, 'Se esperaba :');
    
    final instrucciones = _instrucciones();
    
    _consume(TokenType.fin, 'Se esperaba FIN');
    _consume(TokenType.si, 'Se esperaba SI');
    
    return CondicionalNode(
      condicion: condicion,
      instrucciones: instrucciones,
    );
  }

  // Ciclo = "REPETIR" "[" Variable "]" "VECES" ":" Instrucciones "FIN" "REPETIR"
  CicloNode _ciclo() {
    _consume(TokenType.repetir, 'Se esperaba REPETIR');
    _consume(TokenType.corcheteAbre, 'Se esperaba [');
    final variable = _consume(TokenType.identificador, 'Se esperaba nombre de variable');
    _consume(TokenType.corcheteCierra, 'Se esperaba ]');
    _consume(TokenType.veces, 'Se esperaba VECES');
    _consume(TokenType.dobleComa, 'Se esperaba :');
    
    final instrucciones = _instrucciones();
    
    _consume(TokenType.fin, 'Se esperaba FIN');
    _consume(TokenType.repetir, 'Se esperaba REPETIR');
    
    return CicloNode(
      variable: variable.lexeme,
      instrucciones: instrucciones,
    );
  }

  // Condicion = Variable Comparador Valor
  CondicionNode _condicion() {
    final variable = _consume(TokenType.identificador, 'Se esperaba variable');
    
    String comparador;
    if (_check(TokenType.igualIgual)) {
      comparador = '==';
      _advance();
    } else if (_check(TokenType.menorQue)) {
      comparador = '<';
      _advance();
    } else if (_check(TokenType.mayorQue)) {
      comparador = '>';
      _advance();
    } else {
      throw Exception('Se esperaba comparador (==, <, >)');
    }
    
    final valor = _valor();
    
    return CondicionNode(
      variable: variable.lexeme,
      comparador: comparador,
      valor: valor,
    );
  }

  // Valor = numero | variable
  ASTNode _valor() {
    if (_check(TokenType.numero)) {
      final token = _advance();
      return NumeroNode(valor: token.literal as int);
    }
    
    if (_check(TokenType.identificador)) {
      final token = _advance();
      return VariableNode(nombre: token.lexeme);
    }
    
    throw Exception('Se esperaba número o variable');
  }

  // === Métodos auxiliares ===

  Token _consume(TokenType type, String message) {
    if (_check(type)) return _advance();
    
    final current = _peek();
    throw Exception('$message en línea ${current.line}, columna ${current.column}. '
                   'Se encontró: ${current.lexeme}');
  }

  bool _check(TokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  bool _checkNext(TokenType type) {
    if (_current + 1 >= tokens.length) return false;
    return tokens[_current + 1].type == type;
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  bool _isAtEnd() {
    return _peek().type == TokenType.finArchivo;
  }

  Token _peek() {
    return tokens[_current];
  }

  Token _previous() {
    return tokens[_current - 1];
  }
}
