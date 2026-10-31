import 'lexer/lexer.dart';
import 'parser/parser.dart';
import 'syntax_help.dart';

/// Un error del programa, ya explicado: la frase, la pista y el cuadrito de ejemplo.
class ErrorCodigo {
  /// Línea del error (empieza en 1), o null si no se sabe (p. ej. errores de ejecución).
  final int? linea;

  /// "❌ ..." + "👉 ..." + (opcional) "📖 título" con el código de ejemplo.
  final String mensaje;

  const ErrorCodigo(this.linea, this.mensaje);
}

class ValidationResult {
  final bool isValid;
  final int? errorLine;
  final String? errorMessage;

  /// TODOS los errores del programa, ordenados por línea (vacía si compila).
  final List<ErrorCodigo> errores;

  const ValidationResult.valid()
      : isValid = true,
        errorLine = null,
        errorMessage = null,
        errores = const [];

  const ValidationResult.error(this.errorLine, this.errorMessage,
      [this.errores = const []])
      : isValid = false;
}

class SyntaxValidator {
  final List<String> customCommands;

  /// Cuántos errores se buscan como máximo (más de eso ya es abrumador).
  static const _maxErrores = 8;

  SyntaxValidator({this.customCommands = const []});

  ValidationResult validate(String source, {List<String> comandosPersonalizados = const []}) {
    if (source.trim().isEmpty) return const ValidationResult.valid();

    final cmds = comandosPersonalizados.isNotEmpty
        ? comandosPersonalizados
        : customCommands;
    final errores = encontrarErrores(source, cmds);
    if (errores.isEmpty) return const ValidationResult.valid();

    // El primero que encontró el parser es el que decide si se puede compilar.
    final primero = errores.first;
    final ordenados = [...errores]..sort(_porLinea);
    return ValidationResult.error(primero.linea, primero.mensaje, ordenados);
  }

  /// Busca todos los errores, no solo el primero.
  ///
  /// El parser se detiene en el primer error. Para seguir, se ARREGLA el texto
  /// justo donde falló (sin agregar ni quitar líneas, así los números de línea
  /// siguen siendo los del editor) y se vuelve a analizar. Los arreglos no
  /// inventan errores nuevos: una orden mala se cambia por `AVANZAR 0` (válida),
  /// una cabecera mala de SI/REPETIR por una cabecera correcta, etc.
  List<ErrorCodigo> encontrarErrores(String fuente, [List<String> comandos = const []]) {
    final errores = <ErrorCodigo>[];
    final vistos  = <String>{};
    var texto = fuente;

    for (var i = 0; i < _maxErrores; i++) {
      final r = _analizarUnaVez(texto, comandos);
      if (r == null) break;

      final (msg, linea) = r;
      // Si el mismo error vuelve a salir en la misma línea, no hay progreso.
      if (!vistos.add('$linea|${msg.split('\n').first}')) break;

      errores.add(ErrorCodigo(linea, _enrichMessage(fuente, linea, msg)));

      final nuevo = _reparar(texto, linea, msg);
      if (nuevo == texto) break;
      texto = nuevo;

      // Después de un texto sobrante tras FIN PROGRAMA, lo que siga es ruido.
      if (msg.contains('hay texto después de FIN PROGRAMA')) break;
    }
    return errores;
  }

  /// Analiza una vez: null si compila; si no, (mensaje, línea).
  (String, int?)? _analizarUnaVez(String texto, List<String> comandos) {
    try {
      Parser(AnalizadorLexico(texto, comandosPersonalizados: comandos).tokenizar())
          .parsePrograma();
      return null;
    } catch (e) {
      final msg = e.toString();
      return (msg, _extractLine(msg));
    }
  }

  /// Arregla el texto en el lugar del error, SIN cambiar el número de líneas.
  String _reparar(String texto, int? linea, String msg) {
    final l = texto.split('\n');
    final n = l.length;
    var idx = linea == null ? n - 1 : linea - 1;
    if (idx < 0) idx = 0;
    if (idx > n - 1) idx = n - 1;
    final ln = l[idx];

    String poner(String nuevo) {
      l[idx] = nuevo;
      return l.join('\n');
    }

    // ── estructura del programa ──
    if (msg.contains('falta el final del programa')) {
      l[n - 1] = '${l[n - 1]} FIN PROGRAMA';
      return l.join('\n');
    }
    if (msg.contains('tiene que empezar con la palabra PROGRAMA')) {
      return poner('PROGRAMA "x" $ln');
    }
    if (msg.contains('a PROGRAMA le falta el nombre')) {
      return poner(ln.replaceFirst(
          RegExp(r'\bPROGRAMA\b', caseSensitive: false), 'PROGRAMA "x"'));
    }
    if (msg.contains('el SI no se cerró')) return poner('FIN SI $ln');
    if (msg.contains('el REPETIR no se cerró')) return poner('FIN REPETIR $ln');
    if (msg.contains('no hay ningún SI abierto') ||
        msg.contains('no hay ningún REPETIR abierto') ||
        msg.contains('hay texto después de FIN PROGRAMA')) {
      return poner('');
    }
    if (msg.contains('tu programa está vacío')) return poner('AVANZAR 0 $ln');
    if (msg.contains('este bloque está vacío')) return poner('$ln AVANZAR 0');

    // ── cabeceras de SI / REPETIR: se cambian por una cabecera correcta ──
    final p = _primeraPalabra(ln);
    if (p == 'SI') return poner('SI N < 0 ENTONCES:');
    if (p == 'REPETIR') return poner('REPETIR [N] VECES:');

    // ── cualquier otra línea: una orden o asignación mal escrita. Se cambia
    //    por una orden neutra y válida (en blanco, si era la única orden de un
    //    SI o REPETIR el bloque quedaría vacío y saldría un error inventado) ──
    return poner('AVANZAR 0');
  }

  String _primeraPalabra(String linea) {
    final m = RegExp(r'^\s*([A-Za-z_]+)').firstMatch(linea);
    return m == null ? '' : m.group(1)!.toUpperCase();
  }

  static int _porLinea(ErrorCodigo a, ErrorCodigo b) =>
      (a.linea ?? (1 << 30)).compareTo(b.linea ?? (1 << 30));

  /// Agrega al final del mensaje un cuadrito con el ejemplo de cómo se escribe
  /// bien el bloque en el que está el error.
  String _enrichMessage(String source, int? line, String msg) {
    final ejemplo = AyudaSintaxis.para(source, line, mensaje: msg);
    if (ejemplo == null) return msg;
    final codigo = ejemplo.codigo.split('\n').map((l) => '   $l').join('\n');
    return '$msg\n📖 ${ejemplo.titulo}\n$codigo';
  }

  int? _extractLine(String message) {
    final match = RegExp(r'[Ll]ínea\s+(\d+)').firstMatch(message);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }
}
