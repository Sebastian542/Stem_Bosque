import 'interpreter/interpreter.dart';
import 'models/token.dart';
import 'lexer/lexer.dart';
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
  final List<String> comandosPersonalizados;

  Compilador({this.comandosPersonalizados = const []});

  ResultadoCompilacion compilar(String fuente) {
    try {
      final lexer = AnalizadorLexico(fuente, comandosPersonalizados: comandosPersonalizados);
      final tokens = lexer.tokenizar();
      final ast    = Parser(tokens).parsePrograma();
      final astTexto = ast.mostrar('');

      final interprete = Interprete()..ejecutar(ast);

      // Un error de ejecución (variable sin definir, demasiados pasos...) es un
      // error de compilación para el usuario: no se debe simular ni enviar un
      // programa que quedó a medias.
      if (interprete.error != null) {
        return ResultadoCompilacion.error(interprete.error!);
      }

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

/// Junta los comandos seguidos que son del mismo tipo y van hacia el mismo lado:
///
///   AVANZAR 10, AVANZAR 10, AVANZAR 10, AVANZAR 10   →   AVANZAR 40
///   GIRAR 90 (cuatro veces)                          →   GIRAR 360
///
/// Así el robot hace el movimiento completo de una vez, sin arrancar y frenar
/// los motores en cada repetición de un REPETIR. La posición y el ángulo con
/// los que termina son exactamente los mismos.
///
/// No junta comandos distintos (AVANZAR con GIRAR: el orden importa) ni los
/// que van en sentidos contrarios (AVANZAR 10 con AVANZAR -10), y respeta los
/// límites por comando del script de la Raspberry (500 cm y 3600°): si el
/// total los pasa, lo parte en varios comandos grandes.
List<String> fusionarComandos(List<String> comandos) {
  const maxCm     = 500.0;  // MAX_CM_POR_COMANDO en stemBosque_motor_executor.py
  const maxGrados = 3600.0; // MAX_GRADOS_POR_COMANDO (10 vueltas)

  final salida = <String>[];
  String? tipo;
  var total = 0.0;

  void volcar() {
    final t = tipo;
    if (t == null) return;
    final limite = t == 'GIRAR' ? maxGrados : maxCm;
    final signo  = total < 0 ? -1.0 : 1.0;
    var resto    = total.abs();
    while (resto > limite + 1e-9) {
      salida.add('$t ${_numeroComando(signo * limite)}');
      resto -= limite;
    }
    final ultimo = _numeroComando(signo * resto);
    if (ultimo != '0') salida.add('$t $ultimo');
    tipo  = null;
    total = 0;
  }

  for (final linea in comandos) {
    final partes = linea.trim().split(RegExp(r'\s+'));
    final valor  = partes.length == 2 ? double.tryParse(partes[1]) : null;

    // Una línea que no es GIRAR/AVANZAR con un número se deja tal cual.
    if (valor == null || (partes[0] != 'AVANZAR' && partes[0] != 'GIRAR')) {
      volcar();
      salida.add(linea);
      continue;
    }

    // Un comando de 0 no mueve nada: se ignora y no corta la racha.
    if (valor == 0) continue;

    final mismoTipo  = tipo == partes[0];
    final mismoSigno = (valor < 0) == (total < 0);
    if (tipo != null && !(mismoTipo && mismoSigno)) volcar();

    tipo   = partes[0];
    total += valor;
  }
  volcar();
  return salida;
}

/// Mismo formato que el intérprete: 4 decimales, sin ruido de punto flotante y
/// sin notación científica (el robot no la entiende).
String _numeroComando(double n) {
  final r = double.parse(n.toStringAsFixed(4));
  if (r == 0) return '0';
  return (r == r.truncateToDouble() && r.abs() < 1e15)
      ? r.toInt().toString()
      : r.toString();
}