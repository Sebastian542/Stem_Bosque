import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Guía del lenguaje. Dos pestañas:
///  · Conceptos → explica, con palabras sencillas y ejemplos, qué es cada cosa.
///  · Comandos  → referencia rápida de cómo se escribe cada instrucción.
class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        backgroundColor: AppTheme.currentLine,
        surfaceTintColor: Colors.transparent,
        insetPadding: r.dialogInsets,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppTheme.selection, width: AppTheme.borde),
        ),
        titlePadding: EdgeInsets.zero,
        title: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  Icon(Icons.school_rounded, color: AppTheme.cyan),
                  SizedBox(width: 12),
                  Text(
                    'Guía del lenguaje',
                    style: TextStyle(
                      color: AppTheme.foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              labelColor: AppTheme.cyan,
              unselectedLabelColor: AppTheme.comment,
              indicatorColor: AppTheme.cyan,
              dividerColor: AppTheme.currentLine,
              tabs: const [
                Tab(text: 'Conceptos'),
                Tab(text: 'Comandos'),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: r.dialogMaxWidth,
          height: r.dialogListHeight,
          child: TabBarView(
            children: [
              _buildConceptosTab(),
              _buildComandosTab(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ENTENDIDO',
              style: TextStyle(
                color: AppTheme.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PESTAÑA 1 — CONCEPTOS (didáctica)
  // ═══════════════════════════════════════════════════════════════════════

  static const _conceptos = <_Concepto>[
    _Concepto(
      icono: Icons.flag_rounded,
      color: AppTheme.pink,
      titulo: 'Un programa',
      texto: 'Un programa es una lista de órdenes para tu robot. Siempre '
          'empieza con la palabra PROGRAMA y termina con FIN PROGRAMA. '
          'Lo que va en medio es lo que el robot hará, de arriba hacia abajo.',
      codigo: 'PROGRAMA "Mi robot"\n'
          '  AVANZAR 20\n'
          '  GIRAR 90\n'
          'FIN PROGRAMA',
    ),
    _Concepto(
      icono: Icons.label_rounded,
      color: AppTheme.yellow,
      titulo: 'El nombre del programa',
      texto: 'Es lo que va entre comillas después de PROGRAMA. Puedes '
          'ponerle el que quieras: el robot no lo usa para moverse, es solo '
          'para que tú reconozcas tu programa.',
      codigo: 'PROGRAMA "Carrera veloz"',
      nota: 'Las comillas " " siempre se abren y se cierran.',
    ),
    _Concepto(
      icono: Icons.stop_circle_outlined,
      color: AppTheme.pink,
      titulo: 'FIN',
      texto: 'FIN quiere decir "aquí termina". Siempre lleva al lado lo que '
          'estás cerrando: FIN PROGRAMA cierra el programa, FIN SI cierra un '
          'SI y FIN REPETIR cierra un REPETIR. Si abres algo, ¡acuérdate de '
          'cerrarlo!',
    ),
    _Concepto(
      icono: Icons.arrow_upward_rounded,
      color: AppTheme.cyan,
      titulo: 'AVANZAR',
      texto: 'Hace que el robot camine en línea recta. El número son '
          'centímetros. Si pones un número negativo, ¡va hacia atrás!',
      codigo: 'AVANZAR 20   // adelante 20 cm\n'
          'AVANZAR -5   // atrás 5 cm',
    ),
    _Concepto(
      icono: Icons.rotate_right_rounded,
      color: AppTheme.cyan,
      titulo: 'GIRAR',
      texto: 'Hace que el robot gire sin moverse de su lugar. El número son '
          'grados: 90 es un cuarto de vuelta y 360 es una vuelta completa. '
          'Positivo gira a la derecha; negativo, a la izquierda.',
      codigo: 'GIRAR 90    // derecha\n'
          'GIRAR -45   // izquierda',
    ),
    _Concepto(
      icono: Icons.inventory_2_outlined,
      color: AppTheme.green,
      titulo: 'Variables',
      texto: 'Una variable es una cajita con nombre donde guardas un número '
          'para usarlo después. Se escribe el nombre, un signo = y el número '
          '(o una función como COS).',
      codigo: 'Pasos = 5\n'
          'N = 10\n'
          'A = COS(60)',
      nota: 'El nombre lleva letras y números, sin espacios ni tildes.',
    ),
    _Concepto(
      icono: Icons.repeat_rounded,
      color: AppTheme.pink,
      titulo: 'REPETIR',
      texto: 'Repite las órdenes de adentro varias veces, para no escribirlas '
          'una y otra vez. Cuántas veces lo dice la variable entre corchetes; '
          'por eso primero hay que darle un valor.',
      codigo: 'N = 4\n'
          'REPETIR [N] VECES:\n'
          '  AVANZAR 20\n'
          '  GIRAR 90\n'
          'FIN REPETIR',
      nota: '¡Este programa dibuja un cuadrado!',
    ),
    _Concepto(
      icono: Icons.call_split_rounded,
      color: AppTheme.pink,
      titulo: 'SI',
      texto: 'Decide si el robot hace algo o no. Compara una variable con un '
          'número y, solo si se cumple, hace lo de adentro. Puedes comparar '
          'con < (menor que), > (mayor que) o == (igual a).',
      codigo: 'N = 3\n'
          'SI N < 10 ENTONCES:\n'
          '  AVANZAR 5\n'
          'FIN SI',
    ),
    _Concepto(
      icono: Icons.sticky_note_2_outlined,
      color: AppTheme.comment,
      titulo: 'Notas',
      texto: 'Puedes escribir notas para ti y el robot las ignora. Con // la '
          'nota llega hasta el final de la línea; con /* y */ puede ocupar '
          'varias líneas.',
      codigo: '// Aquí empieza mi carrera\n'
          '/* una nota más larga */',
    ),
    _Concepto(
      icono: Icons.functions_rounded,
      color: AppTheme.orange,
      titulo: 'SEN, COS y TANG',
      texto: 'Son operaciones de matemáticas con ángulos (en grados). Se '
          'escriben dentro de una orden o al guardar una variable. Dan números '
          'pequeños (entre -1 y 1), así que por ahora sirven más que nada para '
          'experimentar.',
      codigo: 'AVANZAR SEN(30)\n'
          'A = COS(60)',
    ),
    _Concepto(
      icono: Icons.palette_outlined,
      color: AppTheme.purple,
      titulo: 'Los colores del editor',
      texto: 'El editor pinta cada cosa de un color para ayudarte: rosa son '
          'las palabras del lenguaje (KW), celeste las órdenes (CMD), morado '
          'los números (NUM), verde las variables (VAR), amarillo los textos '
          '(STR) y gris las notas.',
    ),
    _Concepto(
      icono: Icons.smart_toy_outlined,
      color: AppTheme.green,
      titulo: 'Simular y enviar',
      texto: 'SIMULAR te muestra cómo se movería un robot perfecto. El robot '
          'de verdad se mueve por tiempo, así que puede diferir un poquito '
          'del simulador: ¡es normal!',
    ),
  ];

  Widget _buildConceptosTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      children: [
        for (final c in _conceptos) _tarjeta(c),
      ],
    );
  }

  Widget _tarjeta(_Concepto c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.currentLine.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: c.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.icono, size: 18, color: c.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.titulo,
                  style: TextStyle(
                    color: c.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.texto,
            style: const TextStyle(
              color: AppTheme.foreground,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (c.codigo != null) ...[
            const SizedBox(height: 8),
            _Codigo(c.codigo!),
          ],
          if (c.nota != null) ...[
            const SizedBox(height: 6),
            Text(
              c.nota!,
              style: const TextStyle(
                color: AppTheme.comment,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PESTAÑA 2 — COMANDOS (referencia rápida)
  // ═══════════════════════════════════════════════════════════════════════

  static const _referencia = <(String, List<(String, String)>)>[
    ('ESTRUCTURA', [
      ('PROGRAMA "nombre"', 'Empieza el programa.'),
      ('FIN PROGRAMA', 'Termina el programa.'),
    ]),
    ('MOVIMIENTO', [
      ('AVANZAR 20', 'Avanza 20 cm (negativo: retrocede).'),
      ('GIRAR 90', 'Gira 90 grados (negativo: a la izquierda).'),
    ]),
    ('VARIABLES', [
      ('N = 10', 'Guarda el número 10 en la variable N.'),
      ('A = COS(60)', 'También puede guardar el resultado de una función.'),
    ]),
    ('DECIDIR Y REPETIR', [
      ('SI N < 10 ENTONCES:\n  ...\nFIN SI', 'Hace lo de adentro solo si se cumple.'),
      ('REPETIR [N] VECES:\n  ...\nFIN REPETIR', 'Repite lo de adentro N veces.'),
    ]),
    ('MATEMÁTICAS', [
      ('SEN(30)  COS(60)  TANG(45)', 'Operaciones con ángulos en grados.'),
    ]),
  ];

  Widget _buildComandosTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      children: [
        for (final grupo in _referencia) ...[
          Text(
            grupo.$1,
            style: const TextStyle(
              color: AppTheme.comment,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in grupo.$2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Codigo(item.$1),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: AppTheme.currentLine),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// DATOS Y WIDGETS AUXILIARES
// ═════════════════════════════════════════════════════════════════════════

class _Concepto {
  final IconData icono;
  final Color    color;
  final String   titulo;
  final String   texto;
  final String?  codigo;
  final String?  nota;

  const _Concepto({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.texto,
    this.codigo,
    this.nota,
  });
}

/// Bloque de código con los mismos colores que el editor.
class _Codigo extends StatelessWidget {
  final String codigo;
  const _Codigo(this.codigo);

  static const _estructura = {
    'PROGRAMA', 'FIN', 'SI', 'ENTONCES', 'REPETIR', 'VECES',
  };
  static const _ordenes = {'GIRAR', 'AVANZAR'};
  static const _funciones = {'SEN', 'COS', 'TANG'};

  static final _partes =
      RegExp(r'"[^"]*"|[0-9]+(?:\.[0-9]+)?|[A-Za-z_][A-Za-z0-9_]*|\s+|.');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.selection, width: 1.5),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontFamily: AppTheme.familiaMono,
            fontSize: 12,
            height: 1.45,
            color: AppTheme.foreground,
          ),
          children: [
            for (final (i, linea) in codigo.split('\n').indexed) ...[
              if (i > 0) const TextSpan(text: '\n'),
              _colorear(linea),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _colorear(String linea) {
    // Línea de nota de varias líneas: /* ... */
    if (linea.trimLeft().startsWith('/*')) {
      return TextSpan(
        text: linea,
        style: const TextStyle(color: AppTheme.comment),
      );
    }

    final iNota  = linea.indexOf('//');
    final codigo = iNota >= 0 ? linea.substring(0, iNota) : linea;
    final nota   = iNota >= 0 ? linea.substring(iNota) : null;

    final spans = <InlineSpan>[];
    for (final m in _partes.allMatches(codigo)) {
      final t = m.group(0)!;
      spans.add(TextSpan(text: t, style: _estilo(t)));
    }
    if (nota != null) {
      spans.add(TextSpan(
        text: nota,
        style: const TextStyle(color: AppTheme.comment),
      ));
    }
    return TextSpan(children: spans);
  }

  TextStyle _estilo(String t) {
    final mayus = t.toUpperCase();
    if (t.startsWith('"')) {
      return const TextStyle(color: AppTheme.yellow);
    }
    if (RegExp(r'^[0-9]').hasMatch(t)) {
      return const TextStyle(color: AppTheme.purple);
    }
    if (_estructura.contains(mayus)) {
      return const TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold);
    }
    if (_ordenes.contains(mayus)) {
      return const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold);
    }
    if (_funciones.contains(mayus)) {
      return const TextStyle(color: AppTheme.orange);
    }
    if (RegExp(r'^[A-Za-z_]').hasMatch(t)) {
      return const TextStyle(color: AppTheme.green);
    }
    return const TextStyle(color: AppTheme.foreground);
  }
}
