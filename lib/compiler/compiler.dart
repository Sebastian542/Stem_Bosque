import 'interpreter/interpreter.dart';
import 'models/token.dart';
import 'lexer/lexer.dart';
import 'ast/nodes.dart';
import 'parser/parser.dart';
import 'codegen/code_generator.dart';

export 'models/token.dart';
export 'lexer/lexer.dart';
export 'ast/nodes.dart';
export 'parser/parser.dart';
export 'codegen/code_generator.dart';

class ResultadoCompilacion {
  final bool exito;
  final List<Token>? tokens;
  final String? ast;
  final List<String>? salidaEjecucion;
  final String? codigoGenerado;
  final String? error;

  ResultadoCompilacion.ok({
    required this.tokens,
    required this.ast,
    required this.salidaEjecucion,
    required this.codigoGenerado,
  })  : exito = true,
        error = null;

  ResultadoCompilacion.error(this.error)
      : exito = false,
        tokens = null,
        ast = null,
        salidaEjecucion = null,
        codigoGenerado = null;
}

class Compilador {
  ResultadoCompilacion compilar(String fuente) {
    try {
      final tokens = AnalizadorLexico(fuente).tokenizar();
      final ast    = Parser(tokens).parsePrograma();
      final astTexto = ast.mostrar('');

      final interprete = Interprete()..ejecutar(ast);
      final codigo     = GeneradorCodigo().generar(ast);

      return ResultadoCompilacion.ok(
        tokens:          tokens,
        ast:             astTexto,
        salidaEjecucion: interprete.salida,
        codigoGenerado:  codigo,
      );
    } catch (e) {
      return ResultadoCompilacion.error(e.toString());
    }
  }
}