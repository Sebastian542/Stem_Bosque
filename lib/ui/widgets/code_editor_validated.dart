import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../compiler/syntax_validator.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'control_editor.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SISTEMA DE TOKENS — solo visual, no toca el compilador
// ═══════════════════════════════════════════════════════════════════════════

enum _TokenKind {
  keyword, command, trig, boolean, number, string, comment, identifier, other
}

class _Token {
  final String text;
  final _TokenKind kind;
  _Token(this.text, this.kind);
}

final _reToken  = RegExp(r'"[^"]*"|[0-9]+(?:\.[0-9]+)?|[A-Za-z_][A-Za-z0-9_]*|[^\s]|\s+');
final _reNumero = RegExp(r'^[0-9]+(?:\.[0-9]+)?$');
final _reLetras = RegExp(r'^[A-Za-z_]+$');
final _reIdent  = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

const _structureKw = {'PROGRAMA', 'FIN', 'SI', 'ENTONCES', 'REPETIR', 'VECES'};
const _commandKw   = {'GIRAR', 'AVANZAR'};
const _trigKw      = {'SEN', 'COS', 'TANG'};
const _boolKw      = {'AND', 'OR', 'NOT'};

/// Colorea una línea. [enBloque] indica si la línea empieza dentro de un
/// comentario `/* ... */` abierto antes; el resultado dice si sigue abierto.
(List<_Token>, bool) _tokenizeLine(
  String line, {
  Iterable<String> customCommands = const [],
  bool enBloque = false,
}) {
  final tokens = <_Token>[];

  void codigo(String trozo) {
    for (final m in _reToken.allMatches(trozo)) {
      final t = m.group(0)!;
      tokens.add(_Token(t, _classifyToken(t, customCommands)));
    }
  }

  var pos = 0;
  while (pos < line.length) {
    if (enBloque) {
      final cierre = line.indexOf('*/', pos);
      final fin = cierre < 0 ? line.length : cierre + 2;
      tokens.add(_Token(line.substring(pos, fin), _TokenKind.comment));
      pos = fin;
      enBloque = cierre < 0;
      continue;
    }

    final linea  = line.indexOf('//', pos);
    final bloque = line.indexOf('/*', pos);
    final inicio = linea < 0
        ? bloque
        : (bloque < 0 ? linea : (linea < bloque ? linea : bloque));
    if (inicio < 0) {
      codigo(line.substring(pos));
      break;
    }

    codigo(line.substring(pos, inicio));
    if (inicio == linea) {
      tokens.add(_Token(line.substring(inicio), _TokenKind.comment));
      break;
    }
    // Abre un comentario de bloque: se cierra en esta línea o en otra.
    final cierre = line.indexOf('*/', inicio + 2);
    final fin = cierre < 0 ? line.length : cierre + 2;
    tokens.add(_Token(line.substring(inicio, fin), _TokenKind.comment));
    pos = fin;
    enBloque = cierre < 0;
  }
  return (tokens, enBloque);
}

_TokenKind _classifyToken(String t, [Iterable<String> customCommands = const []]) {
  if (t.startsWith('"'))     return _TokenKind.string;
  if (_reNumero.hasMatch(t)) return _TokenKind.number;
  if (!_reIdent.hasMatch(t)) return _TokenKind.other;

  if (_reLetras.hasMatch(t)) {
    final up = t.toUpperCase();
    if (_structureKw.contains(up)) return _TokenKind.keyword;
    if (_commandKw.contains(up) || customCommands.contains(up)) {
      return _TokenKind.command;
    }
    if (_trigKw.contains(up)) return _TokenKind.trig;
    if (_boolKw.contains(up)) return _TokenKind.boolean;
  }
  return _TokenKind.identifier;
}

Color _colorFor(_TokenKind kind) {
  switch (kind) {
    case _TokenKind.keyword:    return AppTheme.pink;
    case _TokenKind.command:    return AppTheme.cyan;
    case _TokenKind.trig:       return AppTheme.orange;
    case _TokenKind.boolean:    return AppTheme.purple;
    case _TokenKind.number:     return AppTheme.purple;
    case _TokenKind.string:     return AppTheme.yellow;
    case _TokenKind.comment:    return AppTheme.comment;
    case _TokenKind.identifier: return AppTheme.green;
    case _TokenKind.other:      return AppTheme.foreground;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONTROLADOR CON RESALTADO + GHOST TEXT
// ═══════════════════════════════════════════════════════════════════════════

class CodeEditorController extends TextEditingController {
  String ghostSuffix = '';
  Set<String> customCommands = const {};

  // ── Caché del resaltado ──────────────────────────────────────────────────
  // Al escribir solo cambia una línea: las demás reutilizan sus fragmentos ya
  // coloreados (y Flutter los reconoce como idénticos al comparar).
  // La clave lleva una marca si la línea empieza dentro de un /* abierto.
  final Map<String, (List<InlineSpan>, bool)> _spansPorLinea = {};
  static const _maxLineasEnCache = 4000;

  String _cachedText = '';
  TextSpan? _cachedSpan;
  TextStyle? _cachedStyle;

  void setCustomCommands(List<String> commands) {
    final next = commands.map((c) => c.toUpperCase()).toSet();
    if (next.length == customCommands.length &&
        next.every(customCommands.contains)) {
      return;
    }
    customCommands = next;
    _spansPorLinea.clear();
    _cachedSpan = null;
  }

  (List<InlineSpan>, bool) _spansDeLinea(String linea, bool enBloque) {
    final clave = enBloque ? '\u0000$linea' : linea;
    final guardados = _spansPorLinea[clave];
    if (guardados != null) return guardados;
    if (_spansPorLinea.length > _maxLineasEnCache) _spansPorLinea.clear();

    final (tokens, sigueAbierto) = _tokenizeLine(
      linea,
      customCommands: customCommands,
      enBloque: enBloque,
    );
    return _spansPorLinea[clave] = (
      [
        for (final tk in tokens)
          TextSpan(text: tk.text, style: _estiloToken(tk.kind)),
      ],
      sigueAbierto,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final cached = _cachedSpan;
    if (cached != null && _cachedText == text && _cachedStyle == style) {
      return cached;
    }

    final lineas   = text.split('\n');
    final children = <InlineSpan>[];
    var enBloque = false;
    for (int i = 0; i < lineas.length; i++) {
      final (spans, sigueAbierto) = _spansDeLinea(lineas[i], enBloque);
      children.addAll(spans);
      enBloque = sigueAbierto;
      if (i < lineas.length - 1) children.add(_saltoDeLinea);
    }

    _cachedText  = text;
    _cachedStyle = style;
    return _cachedSpan = TextSpan(style: style, children: children);
  }
}

const _saltoDeLinea = TextSpan(text: '\n');

final Map<_TokenKind, TextStyle> _estilosToken = {
  for (final kind in _TokenKind.values)
    kind: TextStyle(
      color: _colorFor(kind),
      fontWeight: kind == _TokenKind.keyword || kind == _TokenKind.command
          ? FontWeight.bold
          : FontWeight.normal,
    ),
};

TextStyle _estiloToken(_TokenKind kind) => _estilosToken[kind]!;

// ═══════════════════════════════════════════════════════════════════════════
// SUGERENCIAS
// ═══════════════════════════════════════════════════════════════════════════

const _palabrasClave = [
  'PROGRAMA', 'FIN PROGRAMA', 'FIN REPETIR', 'FIN SI',
  'AVANZAR', 'GIRAR', 'REPETIR', 'VECES', 'SI', 'ENTONCES', 'FIN',
  'SEN', 'COS', 'TANG', 'AND', 'OR', 'NOT',
];

/// Qué hace cada palabra, en lenguaje sencillo (se muestra en el globo).
const _descripciones = {
  'PROGRAMA':     'empieza tu programa',
  'FIN PROGRAMA': 'termina tu programa',
  'FIN REPETIR':  'cierra un REPETIR',
  'FIN SI':       'cierra un SI',
  'FIN':          'aquí termina algo',
  'AVANZAR':      'mueve el robot (cm)',
  'GIRAR':        'gira el robot (grados)',
  'REPETIR':      'repite órdenes',
  'VECES':        'va después de REPETIR [N]',
  'SI':           'hace algo si se cumple',
  'ENTONCES':     'va después de la condición',
  'SEN':          'seno de un ángulo',
  'COS':          'coseno de un ángulo',
  'TANG':         'tangente de un ángulo',
};

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class ValidatedCodeEditor extends StatefulWidget {
  final TextEditingController controller;
  final List<String> customCommands;
  final void Function(bool isValid, String? errorMessage) onValidityChanged;

  /// Se llama con TODOS los errores del programa cada vez que se revisa (vacía
  /// si no hay ninguno). Tita los cuenta y los muestra en una lista.
  final void Function(List<ErrorCodigo> errores)? onErrorsChanged;

  /// Control remoto: deja que Tita lleve el cursor a la línea de un error.
  final ControlEditor? control;

  const ValidatedCodeEditor({
    super.key,
    required this.controller,
    this.customCommands = const [],
    required this.onValidityChanged,
    this.onErrorsChanged,
    this.control,
  });

  @override
  State<ValidatedCodeEditor> createState() => _ValidatedCodeEditorState();
}

class _ValidatedCodeEditorState extends State<ValidatedCodeEditor>
    with SingleTickerProviderStateMixin {
  final _focusNode        = FocusNode();
  final _scrollController = ScrollController();
  final _lineScrollCtrl   = ScrollController();

  final _hScrollController = ScrollController();

  /// (cantidad de líneas, línea del cursor empezando en 0; -1 sin cursor).
  final _infoLineas = ValueNotifier<(int, int)>((1, -1));

  // Globo de sugerencias + texto fantasma: una capa (Overlay) anclada al cursor.
  OverlayEntry? _popupEntry;
  Rect?  _cursorRect;   // línea del cursor, en coordenadas de pantalla
  Rect?  _wordRect;     // palabra que se está escribiendo
  Rect?  _editorRect;   // zona visible del editor
  String _ghost   = ''; // resto de la sugerencia, en gris detrás del cursor
  String _palabra = ''; // palabra que se está escribiendo (mayúsculas)
  bool   _anclajePendiente = false;

  ValidationResult _result      = const ValidationResult.valid();
  List<String>     _sugerencias = [];

  // ── Zoom ──────────────────────────────────────────────────────────────────
  double _fontSize            = 14.0;
  double _fontSizeOnScaleStart = 14.0;
  static const double _minFontSize = 9.0;
  static const double _maxFontSize = 28.0;
  static const double _lineHeight  = 1.5;
  double get _lineH => _fontSize * _lineHeight;

  static const _fontFamily = AppTheme.familiaMono;
  static const _padding    = 8.0;
  bool _fuenteInicial = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fuenteInicial) return;
    _fuenteInicial = true;
    _fontSize = context.responsive.codeFontSize;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_actualizarInfoLineas);
    _actualizarInfoLineas();
    _scrollController.addListener(_onScroll);
    _hScrollController.addListener(_programarAnclaje);
    widget.control?.vincular(_irALinea);
    _syncCustomCommands();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _cerrarPopup();
      } else if (_sugerencias.isNotEmpty) {
        _programarAnclaje(); // volvió el foco o el teclado: recolocar el globo
      }
    });

    // Valida el texto con el que arranca el editor. Sin esto, el botón Compilar
    // no sabe si el programa de ejemplo es válido hasta que el usuario escribe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _validarAhora();
    });
  }

  @override
  void didUpdateWidget(ValidatedCodeEditor old) {
    super.didUpdateWidget(old);
    if (old.control != widget.control) {
      old.control?.desvincular();
      widget.control?.vincular(_irALinea);
    }
    if (old.customCommands != widget.customCommands) {
      _syncCustomCommands();
      _validarAhora();
    }
  }

  void _syncCustomCommands() {
    final editor = widget.controller;
    if (editor is CodeEditorController) {
      editor.setCustomCommands(widget.customCommands);
    }
  }

  @override
  void dispose() {
    widget.control?.desvincular();
    _validationTimer?.cancel();
    _cerrarPopup();
    _focusNode.dispose();
    _hScrollController.dispose();
    _scrollController.dispose();
    _lineScrollCtrl.dispose();
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_actualizarInfoLineas);
    _infoLineas.dispose();
    super.dispose();
  }

  void _actualizarInfoLineas() {
    final value  = widget.controller.value;
    final text   = value.text;
    final cursor = value.selection.baseOffset;
    var lineas = 1;
    var actual = cursor >= 0 ? 0 : -1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        lineas++;
        if (i < cursor) actual++;
      }
    }
    _infoLineas.value = (lineas, actual);
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  Timer? _validationTimer;
  String? _firmaValidacion;
  String? _textoValidado;

  void _onTextChanged() {
    _actualizarSugerencias();

    if (widget.controller.text == _textoValidado) return;
    _validationTimer?.cancel();
    _validationTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted) _validarAhora();
    });
  }

  void _validarAhora() {
    _textoValidado = widget.controller.text;
    final result = SyntaxValidator(customCommands: widget.customCommands)
        .validate(_textoValidado!);
    final firma = '${result.isValid}|${result.errorMessage}|'
        '${result.errores.map((e) => '${e.linea}:${e.mensaje}').join('\u0001')}';
    if (firma == _firmaValidacion) return;
    _firmaValidacion = firma;
    setState(() => _result = result);
    widget.onValidityChanged(
        result.isValid, result.isValid ? null : result.errorMessage);
    widget.onErrorsChanged?.call(result.errores);
  }

  /// Lleva el cursor al final de la línea [linea] (empieza en 1) y la muestra en
  /// pantalla: así, tocar un error de la lista de Tita lleva justo ahí.
  void _irALinea(int linea) {
    final lineas = widget.controller.text.split('\n');
    final i = (linea - 1).clamp(0, lineas.length - 1).toInt();

    var offset = 0;
    for (var k = 0; k < i; k++) {
      offset += lineas[k].length + 1;
    }
    offset += lineas[i].length;

    widget.controller.selection = TextSelection.collapsed(offset: offset);
    _focusNode.requestFocus();

    // Deja la línea más o menos a un tercio de la zona visible.
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      final objetivo = (_padding + i * _lineH - pos.viewportDimension / 3)
          .clamp(0.0, pos.maxScrollExtent)
          .toDouble();
      _scrollController.animateTo(
        objetivo,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScroll() {
    _syncLineScroll();
    _programarAnclaje();
  }

  void _actualizarSugerencias() {
    final text = widget.controller.text;
    final sel  = widget.controller.selection;

    // Solo sugerimos con el cursor quieto (sin texto seleccionado).
    if (!sel.isValid || !sel.isCollapsed || sel.baseOffset > text.length) {
      _limpiarSugerencias();
      return;
    }

    final textHastaCursor = text.substring(0, sel.baseOffset);
    final match = RegExp(r'[A-Za-z_]+$').firstMatch(textHastaCursor);

    if (match == null || match.group(0)!.length < 2) {
      _limpiarSugerencias();
      return;
    }

    final palabraActual = match.group(0)!.toUpperCase();
    final catalogo = [
      ..._palabrasClave,
      ...widget.customCommands.map((c) => c.toUpperCase()),
    ];
    final nuevas = catalogo
        .where((k) => k.startsWith(palabraActual) && k != palabraActual)
        .toList();

    if (nuevas.isEmpty) {
      _limpiarSugerencias();
      return;
    }

    // Texto fantasma: solo si después del cursor no hay nada más en la línea
    // (si lo hubiera, el gris taparía lo que ya está escrito).
    final finDeLinea = text.indexOf('\n', sel.baseOffset);
    final restoLinea =
        text.substring(sel.baseOffset, finDeLinea < 0 ? text.length : finDeLinea);
    _ghost   = restoLinea.trim().isEmpty
        ? nuevas.first.substring(palabraActual.length)
        : '';
    _palabra = palabraActual;

    if (!_listasIguales(_sugerencias, nuevas)) {
      setState(() => _sugerencias = nuevas);
    }
    _programarAnclaje();
  }

  bool _listasIguales(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _limpiarSugerencias() {
    _ghost = '';
    if (_sugerencias.isNotEmpty) {
      setState(() => _sugerencias = []);
    }
    _cerrarPopup();
  }

  // ── Aceptar sugerencia ────────────────────────────────────────────────────

  /// Acepta la sugerencia [sugerencia] reemplazando la palabra que se escribe.
  void _aplicarSugerencia(String sugerencia) {
    final text      = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) return;

    // Misma definición de "palabra actual" que usa _actualizarSugerencias.
    final m = RegExp(r'[A-Za-z_]+$').firstMatch(text.substring(0, cursorPos));
    final inicio = cursorPos - (m?.group(0)!.length ?? 0);

    widget.controller.value = TextEditingValue(
      text:      text.substring(0, inicio) + sugerencia + text.substring(cursorPos),
      selection: TextSelection.collapsed(offset: inicio + sugerencia.length),
    );

    _limpiarSugerencias();
    _focusNode.requestFocus(); // tocar el globo no debe quitarle el foco al editor
  }

  /// Acepta la primera sugerencia (para Tab)
  void _aceptarPrimera() {
    if (_sugerencias.isNotEmpty) {
      _aplicarSugerencia(_sugerencias.first);
    }
  }

  // ── Globo y texto fantasma, anclados al cursor ────────────────────────────

  /// Pide recalcular la posición DESPUÉS de que Flutter dibuje el texto nuevo:
  /// antes de eso, el campo todavía tiene la posición anterior del cursor.
  void _programarAnclaje() {
    if (_sugerencias.isEmpty || _anclajePendiente) return;
    _anclajePendiente = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anclajePendiente = false;
      if (mounted) _actualizarAnclaje();
    });
  }

  /// Le pregunta al propio campo de texto dónde está el cursor en pantalla.
  /// Así el globo queda pegado a la palabra aunque haya zoom, scroll o cambie
  /// el tamaño de letra.
  void _actualizarAnclaje() {
    final sel = widget.controller.selection;
    final editable = _focusNode.context
        ?.findAncestorStateOfType<EditableTextState>()
        ?.renderEditable;

    if (_sugerencias.isEmpty ||
        !_focusNode.hasFocus ||
        editable == null ||
        !editable.attached ||
        !sel.isValid ||
        !sel.isCollapsed) {
      _cerrarPopup();
      return;
    }

    try {
      final caret  = editable.getLocalRectForCaret(sel.extent);
      final inicio = editable.getLocalRectForCaret(TextPosition(
          offset: math.max(0, sel.extentOffset - _palabra.length)));

      final caretTL  = editable.localToGlobal(caret.topLeft);
      final inicioTL = editable.localToGlobal(inicio.topLeft);

      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final visible = box.localToGlobal(Offset.zero) & box.size;

      final cursor = caretTL & caret.size;
      if (!visible.contains(cursor.center)) {
        _cerrarPopup(); // el cursor quedó fuera de la zona visible
        return;
      }

      _cursorRect = cursor;
      _wordRect   = Rect.fromLTRB(
          inicioTL.dx, inicioTL.dy, caretTL.dx, caretTL.dy + caret.height);
      _editorRect = visible;
      _mostrarPopup();
    } catch (_) {
      _cerrarPopup();
    }
  }

  void _mostrarPopup() {
    if (!mounted) return;
    if (_popupEntry == null) {
      _popupEntry = OverlayEntry(builder: _construirOverlay);
      Overlay.of(context).insert(_popupEntry!);
    } else {
      _popupEntry!.markNeedsBuild(); // solo redibujar, sin recrear
    }
  }

  void _cerrarPopup() {
    _popupEntry?.remove();
    _popupEntry = null;
  }

  Widget _construirOverlay(BuildContext ctx) {
    final cursor  = _cursorRect;
    final palabra = _wordRect;
    final editor  = _editorRect;
    if (cursor == null || palabra == null || editor == null ||
        _sugerencias.isEmpty) {
      return const SizedBox.shrink();
    }

    final tecladoH   = MediaQuery.of(ctx).viewInsets.bottom;
    final lineTop    = cursor.center.dy - _lineH / 2;
    final lineBottom = cursor.center.dy + _lineH / 2;
    final mostrar    = _sugerencias.take(4).toList();
    // Alto aproximado: solo sirve para decidir si cabe arriba o abajo.
    final altoGlobo  = mostrar.length * 34.0 + 44.0;

    return LayoutBuilder(builder: (ctx, c) {
      final ancho = math.min(270.0, c.maxWidth - 16);
      final left  = (palabra.left - 14)
          .clamp(8.0, math.max(8.0, c.maxWidth - ancho - 8))
          .toDouble();
      final colaX = ((palabra.left + palabra.width / 2) - left)
          .clamp(16.0, math.max(16.0, ancho - 16.0))
          .toDouble();

      final espacioArriba = lineTop - editor.top;
      final espacioAbajo  = c.maxHeight - tecladoH - lineBottom;
      final arriba = espacioArriba >= altoGlobo + 10 ||
          espacioAbajo < altoGlobo + 10;

      return Stack(
        children: [
          // Texto fantasma: gris, justo detrás de lo que se está escribiendo.
          if (_ghost.isNotEmpty)
            Positioned(
              left: cursor.left,
              top:  lineTop,
              child: IgnorePointer(
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    _ghost,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize:   _fontSize,
                      height:     _lineHeight,
                      decoration: TextDecoration.none,
                      color: AppTheme.foreground.withValues(alpha: 0.32),
                    ),
                  ),
                ),
              ),
            ),

          // Globo con las sugerencias, pegado a la palabra.
          Positioned(
            left:   left,
            width:  ancho,
            top:    arriba ? null : lineBottom + 6,
            bottom: arriba ? c.maxHeight - (lineTop - 6) : null,
            // Agrupa el globo con el campo: tocarlo no cuenta como "tocar afuera".
            child: TextFieldTapRegion(
              child: _GloboSugerencias(
                sugerencias:   mostrar,
                ancho:         ancho,
                colaX:         colaX,
                colaAbajo:     arriba,
                onSeleccionar: _aplicarSugerencia,
                colorFor: (s) => _colorFor(_classifyToken(s.split(' ').first)),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _syncLineScroll() {
    if (_lineScrollCtrl.hasClients) {
      _lineScrollCtrl.jumpTo(_scrollController.offset);
    }
  }

  // ── Pinch-to-zoom ─────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _fontSizeOnScaleStart = _fontSize;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    final newSize = (_fontSizeOnScaleStart * d.scale)
        .clamp(_minFontSize, _maxFontSize);
    if ((newSize - _fontSize).abs() > 0.1) {
      setState(() => _fontSize = newSize);
      _programarAnclaje();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: GestureDetector(
            onScaleStart:  _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: Container(
              color: AppTheme.background,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLineNumbers(),
                  Container(width: AppTheme.borde, color: AppTheme.currentLine),
                  Expanded(child: _buildTextField()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  // ── TextField con manejo de Tab ───────────────────────────────────────────

  Widget _buildTextField() {
    return SingleChildScrollView(
      controller: _hScrollController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 1800,
        // Focus recibe las teclas del TextField, que es quien tiene el foco
        // (antes se creaba un FocusNode nuevo en cada build y nunca las recibía).
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.tab &&
                _sugerencias.isNotEmpty) {
              _aceptarPrimera();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller:        widget.controller,
            focusNode:         _focusNode,
            scrollController:  _scrollController,
            maxLines:          null,
            expands:           true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize:   _fontSize,
              height:     _lineHeight,
              color:      AppTheme.foreground,
            ),
            decoration: const InputDecoration(
              filled:         false,
              border:         InputBorder.none,
              enabledBorder:  InputBorder.none,
              focusedBorder:  InputBorder.none,
              errorBorder:    InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.only(left: _padding, top: _padding),
              isCollapsed:    true,
            ),
            cursorColor:       AppTheme.cyan,
            cursorWidth:       2,
            keyboardType:      TextInputType.multiline,
            autocorrect:       false,
            enableSuggestions: false,
          ),
        ),
      ),
    );
  }

  // ── Números de línea ──────────────────────────────────────────────────────

  Widget _buildLineNumbers() {
    return SizedBox(
      width: 44,
      child: ValueListenableBuilder<(int, int)>(
        valueListenable: _infoLineas,
        builder: (context, info, _) {
          final (cantidad, currentLine) = info;
          final lineasConError = <int>{
            ..._result.errores.map((e) => e.linea).whereType<int>(),
            if (_result.errorLine != null) _result.errorLine!,
          };

          return ListView.builder(
            controller:  _lineScrollCtrl,
            physics:     const NeverScrollableScrollPhysics(),
            padding:     const EdgeInsets.only(top: _padding),
            itemCount:   cantidad,
            itemExtent:  _lineH,
            itemBuilder: (_, i) {
              final num       = i + 1;
              final isError   = lineasConError.contains(num);
              final isCurrent = i == currentLine;

              return SizedBox(
                height: _lineH,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isError
                        ? AppTheme.red.withValues(alpha: 0.12)
                        : isCurrent
                        ? AppTheme.cyan.withValues(alpha: 0.08)
                        : Colors.transparent,
                    border: isCurrent
                        ? const Border(
                        right: BorderSide(color: AppTheme.cyan, width: 2))
                        : null,
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$num',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize:   12,
                      color: isError
                          ? AppTheme.red
                          : isCurrent
                          ? AppTheme.cyan
                          : AppTheme.comment,
                      fontWeight: (isError || isCurrent)
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Status bar ────────────────────────────────────────────────────────────

  static final _estiloContador = AppTheme.fuente(
    fontSize:   11,
    fontWeight: FontWeight.w600,
    color:      AppTheme.comment,
  );

  Widget _buildStatusBar() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    final isValid = _result.isValid;

    final Color color = isEmpty
        ? AppTheme.comment
        : isValid
            ? AppTheme.green
            : AppTheme.orange;
    final IconData icono = isEmpty
        ? Icons.edit_outlined
        : isValid
            ? Icons.check_circle_rounded
            : Icons.error_rounded;
    final String texto = isEmpty
        ? 'Escribe tu programa'
        : isValid
            ? '¡Todo bien!'
            : (_result.errores.length > 1
                ? '${_result.errores.length} cosas por revisar'
                : (_result.errorLine != null
                    ? 'Revisa la línea ${_result.errorLine}'
                    : 'Hay algo por revisar'));

    final r = context.responsive;
    return Container(
      height: r.denseControls ? 32 : 42,
      padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
      decoration: const BoxDecoration(
        color:  AppTheme.background,
        border: Border(
          bottom: BorderSide(color: AppTheme.currentLine, width: 2),
        ),
      ),
      child: Row(
        children: [
          // Estado del programa, en una "píldora" que cambia de color
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, size: 15, color: color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        texto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.fuente(
                          fontSize:   12,
                          fontWeight: FontWeight.w700,
                          color:      color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          ValueListenableBuilder<(int, int)>(
            valueListenable: _infoLineas,
            builder: (_, info, __) => Text(
              info.$1 == 1 ? '1 línea' : '${info.$1} líneas',
              style: _estiloContador,
            ),
          ),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════
// GLOBO DE SUGERENCIAS — un globo de texto pegado a la palabra que se escribe
// ═══════════════════════════════════════════════════════════════════════════

class _GloboSugerencias extends StatelessWidget {
  final List<String>           sugerencias;
  final double                 ancho;
  final double                 colaX;      // dónde apunta la colita (desde la izquierda)
  final bool                   colaAbajo;  // true: el globo está ARRIBA de la palabra
  final void Function(String) onSeleccionar;
  final Color Function(String) colorFor;

  const _GloboSugerencias({
    required this.sugerencias,
    required this.ancho,
    required this.colaX,
    required this.colaAbajo,
    required this.onSeleccionar,
    required this.colorFor,
  });

  static const _fondo = AppTheme.currentLine;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(sugerencias.first);

    final cuerpo = Container(
      width: ancho,
      decoration: BoxDecoration(
        color:        _fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sugerencias.length; i++)
              _fila(sugerencias[i], destacada: i == 0),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Text(
                'Toca una para escribirla',
                style: TextStyle(
                  fontSize: 10,
                  color:    AppTheme.comment.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final cola = Padding(
      padding: EdgeInsets.only(left: colaX - 8),
      child: CustomPaint(
        size: const Size(16, 8),
        painter: _ColaGlobo(
          borde:      color.withValues(alpha: 0.55),
          fondo:      _fondo,
          haciaAbajo: colaAbajo,
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: colaAbajo ? [cuerpo, cola] : [cola, cuerpo],
      ),
    );
  }

  Widget _fila(String s, {required bool destacada}) {
    final color = colorFor(s);
    return InkWell(
      onTap: () => onSeleccionar(s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: destacada ? color.withValues(alpha: 0.10) : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        color.withValues(alpha: destacada ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                s,
                style: TextStyle(
                  fontFamily: AppTheme.familiaMono,
                  fontSize:   12,
                  color:      color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _descripciones[s] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color:    AppTheme.comment,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colita triangular del globo, que apunta a la palabra.
class _ColaGlobo extends CustomPainter {
  final Color borde;
  final Color fondo;
  final bool  haciaAbajo;
  const _ColaGlobo({
    required this.borde,
    required this.fondo,
    required this.haciaAbajo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = Path();
    final lados   = Path();
    if (haciaAbajo) {
      relleno
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
      lados
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
    } else {
      relleno
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width / 2, 0)
        ..close();
      lados
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
    }
    canvas.drawPath(relleno, Paint()..color = fondo);
    canvas.drawPath(
      lados,
      Paint()
        ..color       = borde
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_ColaGlobo old) =>
      old.borde != borde || old.fondo != fondo || old.haciaAbajo != haciaAbajo;
}
