import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stem_bosque/ui/theme/app_theme.dart';
import 'package:stem_bosque/ui/widgets/code_editor_validated.dart';

Color? _colorDe(TextSpan raiz, String palabra) {
  for (final s in raiz.children!.whereType<TextSpan>()) {
    if (s.text == palabra) return s.style?.color;
  }
  return null;
}

void main() {
  testWidgets('el resaltado conserva el texto y colorea cada palabra',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));

    const programa = 'PROGRAMA "demo"\n'
        'REPETIR 3 VECES\n'
        '  AVANZAR 10.5 // adelante\n'
        '  SALTAR\n'
        'FIN REPETIR\n'
        'SI x > 2 AND NOT y ENTONCES\n'
        '  GIRAR SEN(30)\n'
        'FIN SI\n'
        'FIN PROGRAMA';

    final ctrl = CodeEditorController()
      ..setCustomCommands(['saltar'])
      ..text = programa;

    final span = ctrl.buildTextSpan(context: ctx, withComposing: false);
    expect(span.toPlainText(), programa);

    expect(_colorDe(span, 'PROGRAMA'), AppTheme.pink);
    expect(_colorDe(span, 'AVANZAR'), AppTheme.cyan);
    expect(_colorDe(span, 'SALTAR'), AppTheme.cyan);
    expect(_colorDe(span, 'SEN'), AppTheme.orange);
    expect(_colorDe(span, 'AND'), AppTheme.purple);
    expect(_colorDe(span, '10.5'), AppTheme.purple);
    expect(_colorDe(span, '"demo"'), AppTheme.yellow);
    expect(_colorDe(span, '// adelante'), AppTheme.comment);
    expect(_colorDe(span, 'x'), AppTheme.green);

    // Mismo texto: devuelve el mismo objeto (Flutter no vuelve a medir nada).
    expect(identical(ctrl.buildTextSpan(context: ctx, withComposing: false), span),
        isTrue);

    // Cambia una línea: el resto se reutiliza y el texto sigue completo.
    ctrl.text = programa.replaceFirst('3 VECES', '4 VECES');
    final otro = ctrl.buildTextSpan(context: ctx, withComposing: false);
    expect(otro.toPlainText(), ctrl.text);
    expect(_colorDe(otro, '4'), AppTheme.purple);

    // Sin el comando personalizado, SALTAR deja de ser una orden.
    ctrl.setCustomCommands(const []);
    final sinComando = ctrl.buildTextSpan(context: ctx, withComposing: false);
    expect(_colorDe(sinComando, 'SALTAR'), AppTheme.green);

    ctrl.dispose();
  });

  testWidgets('los comentarios /* */ se colorean, aunque ocupen varias líneas',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));

    const programa = '/*Un ejemplo*/\n'
        'PROGRAMA "a" /* nota\n'
        'AVANZAR 5 sigue\n'
        'fin */ AVANZAR 3\n'
        'FIN PROGRAMA';
    final ctrl = CodeEditorController()..text = programa;
    final span = ctrl.buildTextSpan(context: ctx, withComposing: false);

    expect(span.toPlainText(), programa);
    expect(_colorDe(span, '/*Un ejemplo*/'), AppTheme.comment);
    expect(_colorDe(span, '/* nota'), AppTheme.comment);
    expect(_colorDe(span, 'AVANZAR 5 sigue'), AppTheme.comment);
    expect(_colorDe(span, 'fin */'), AppTheme.comment);
    expect(_colorDe(span, 'AVANZAR'), AppTheme.cyan); // el de después del */
    expect(_colorDe(span, '3'), AppTheme.purple);

    // Cerrar el comentario antes cambia el color de las líneas siguientes.
    ctrl.text = programa.replaceFirst('/* nota', '/* nota */');
    final otro = ctrl.buildTextSpan(context: ctx, withComposing: false);
    expect(otro.toPlainText(), ctrl.text);
    expect(_colorDe(otro, 'sigue'), AppTheme.green);

    ctrl.dispose();
  });
}
