import 'package:flutter/material.dart';
import '../../compiler/syntax_validator.dart';
import '../theme/app_theme.dart';

// ── Categorías de tokens para colorear ──────────────────────────────────────

enum _TokenKind { keyword, command, trig, boolean, number, string, comment, identifier, other }

class _Token {
  final String text;
  final _TokenKind kind;
  _Token(this.text, this.kind);
}

// ── Tokenizador de colores (léxico simplificado solo para colores) ──────────

List<_Token> _tokenizeLine(String line) {
  // Comentarios de línea
  final commentIdx = line.indexOf('//');
  String code    = commentIdx >= 0 ? line.substring(0, commentIdx) : line;
  String? comment = commentIdx >= 0 ? line.substring(commentIdx) : null;

  final tokens = <_Token>[];

  // Regex para dividir: strings, números, identificadores/keywords, otros
  final re = RegExp(r'"[^"]*"|[0-9]+(?:\.[0-9]+)?|[A-Za-z_][A-Za-z0-9_]*|[^\s]|\s+');

  for (final m in re.allMatches(code)) {
    final raw = m.group(0)!;
    tokens.add(_Token(raw, _classifyToken(raw)));
  }

  if (comment != null) {
    tokens.add(_Token(comment, _TokenKind.comment));
  }

  return tokens;
}

_TokenKind _classifyToken(String t) {
  final up = t.toUpperCase();

  // Keywords de estructura
  const structureKw = {
    'PROGRAMA', 'FIN', 'SI', 'ENTONCES', 'REPETIR', 'VECES',
  };
  // Comandos de movimiento
  const commandKw = {'GIRAR', 'AVANZAR'};
  // Trigonométricas
  const trigKw = {'SEN', 'COS', 'TANG'};
  // Booleanos
  const boolKw = {'AND', 'OR', 'NOT'};

  if (t.startsWith('"')) return _TokenKind.string;
  if (RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(t)) return _TokenKind.number;
  if (structureKw.contains(up) && RegExp(r'^[A-Za-z_]+$').hasMatch(t)) return _TokenKind.keyword;
  if (commandKw.contains(up) && RegExp(r'^[A-Za-z_]+$').hasMatch(t)) return _TokenKind.command;
  if (trigKw.contains(up) && RegExp(r'^[A-Za-z_]+$').hasMatch(t)) return _TokenKind.trig;
  if (boolKw.contains(up) && RegExp(r'^[A-Za-z_]+$').hasMatch(t)) return _TokenKind.boolean;
  if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(t)) return _TokenKind.identifier;
  return _TokenKind.other;
}

Color _colorFor(_TokenKind kind) {
  switch (kind) {
    case _TokenKind.keyword:    return AppTheme.pink;       // PROGRAMA, FIN, SI, ENTONCES, REPETIR, VECES
    case _TokenKind.command:    return AppTheme.cyan;       // GIRAR, AVANZAR
    case _TokenKind.trig:       return AppTheme.orange;     // SEN, COS, TANG
    case _TokenKind.boolean:    return AppTheme.purple;     // AND, OR, NOT
    case _TokenKind.number:     return AppTheme.purple;     // números
    case _TokenKind.string:     return AppTheme.yellow;     // "texto"
    case _TokenKind.comment:    return AppTheme.comment;    // // comentario
    case _TokenKind.identifier: return AppTheme.green;      // variables
    case _TokenKind.other:      return AppTheme.foreground; // operadores, puntuación
  }
}

// ── Construye un TextSpan coloreado para una línea ──────────────────────────

TextSpan _buildLineSpan(String line, {bool isError = false}) {
  if (isError) {
    // Línea de error: fondo rojo suave, texto rojo
    return TextSpan(
      text: line,
      style: const TextStyle(
        color:               AppTheme.red,
        decoration:          TextDecoration.underline,
        decorationColor:     AppTheme.red,
        decorationStyle:     TextDecorationStyle.wavy,
        decorationThickness: 2,
      ),
    );
  }

  final tks = _tokenizeLine(line);
  return TextSpan(
    children: tks.map((tk) {
      final isBold = tk.kind == _TokenKind.keyword || tk.kind == _TokenKind.command;
      return TextSpan(
        text:  tk.text,
        style: TextStyle(
          color:      _colorFor(tk.kind),
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      );
    }).toList(),
  );
}

// ── Sugerencias ─────────────────────────────────────────────────────────────

const _palabrasClave = [
  'PROGRAMA', 'FIN PROGRAMA', 'FIN REPETIR', 'FIN SI',
  'AVANZAR', 'GIRAR', 'REPETIR', 'VECES', 'SI', 'ENTONCES', 'FIN',
  'AND', 'OR', 'NOT', 'SEN', 'COS', 'TANG',
];

// ── Controlador Personalizado para Resaltado de Sintaxis ─────────────────────

class _SyntaxHighlightingController extends TextEditingController {
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final lines = text.split('\n');
    final children = <TextSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Aquí podríamos integrar el errorLine si lo pasamos al controlador, 
      // pero por simplicidad de la refactorización usaremos el tokenizador base.
      children.add(_buildLineSpan(line));
      if (i < lines.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(style: style, children: children);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ValidatedCodeEditor
// ════════════════════════════════════════════════════════════════════════════

class ValidatedCodeEditor extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool> onValidityChanged;

  const ValidatedCodeEditor({
    super.key,
    required this.controller,
    required this.onValidityChanged,
  });

  @override
  State<ValidatedCodeEditor> createState() => _ValidatedCodeEditorState();
}

class _ValidatedCodeEditorState extends State<ValidatedCodeEditor> {
  final _validator = SyntaxValidator();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _lineScrollCtrl = ScrollController();

  ValidationResult _result = const ValidationResult.valid();
  List<String> _sugerencias = [];

  static const _fontSize = 15.0;
  static const _lineHeight = 1.5;
  static const _lineH = _fontSize * _lineHeight;
  static const _padding = 12.0;

  TextStyle get _codeBaseStyle => AppTheme.codeStyle.copyWith(
        fontSize: _fontSize,
        height: _lineHeight,
        color: AppTheme.foreground,
      );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _scrollController.addListener(_syncLineScroll);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    _lineScrollCtrl.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final result = _validator.validate(widget.controller.text);
    if (mounted) {
      setState(() => _result = result);
      widget.onValidityChanged(result.isValid);
    }
    _actualizarSugerencias();
  }

  void _actualizarSugerencias() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) {
      setState(() => _sugerencias = []);
      return;
    }

    final textHastaCursor = text.substring(0, cursorPos);
    final match = RegExp(r'[A-Za-z_]+$').firstMatch(textHastaCursor);
    if (match == null || match.group(0)!.length < 2) {
      setState(() => _sugerencias = []);
      return;
    }

    final palabraActual = match.group(0)!.toUpperCase();
    setState(() {
      _sugerencias = _palabrasClave
          .where((k) => k.startsWith(palabraActual) && k != palabraActual)
          .toList();
    });
  }

  void _aplicarSugerencia(String sugerencia) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    int inicio = cursorPos - 1;
    while (inicio >= 0 && text[inicio] != ' ' && text[inicio] != '\n') {
      inicio--;
    }
    inicio++;

    final nuevoTexto =
        text.substring(0, inicio) + sugerencia + text.substring(cursorPos);
    final nuevoCursor = inicio + sugerencia.length;
    widget.controller.value = TextEditingValue(
      text: nuevoTexto,
      selection: TextSelection.collapsed(offset: nuevoCursor),
    );
    setState(() => _sugerencias = []);
  }

  void _syncLineScroll() {
    if (_lineScrollCtrl.hasClients) {
      _lineScrollCtrl.jumpTo(_scrollController.offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusBar(),
        if (_sugerencias.isNotEmpty) _buildSuggestionBar(),
        Expanded(child: _buildEditorArea()),
        if (!_result.isValid && _result.errorMessage != null)
          _buildErrorBanner(_result.errorMessage!),
      ],
    );
  }

  Widget _buildEditorArea() {
    return Container(
      color: AppTheme.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLineNumbers(),
          Container(width: 1, color: AppTheme.currentLine),
          Expanded(child: _buildTextField()),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      scrollController: _scrollController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      autocorrect: false,
      enableSuggestions: false,
      style: _codeBaseStyle,
      cursorColor: AppTheme.cyan,
      cursorWidth: 2,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(_padding),
        isCollapsed: true,
        filled: false,
      ),
    );
  }

  Widget _buildLineNumbers() {
    return SizedBox(
      width: 44,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final lines = value.text.split('\n');
          final errorLine = _result.errorLine;
          return ListView.builder(
            controller: _lineScrollCtrl,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: _padding),
            itemCount: lines.length,
            itemBuilder: (_, i) {
              final num = i + 1;
              final isError = errorLine != null && num == errorLine;
              return SizedBox(
                height: _lineH,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: isError
                      ? AppTheme.red.withValues(alpha: 0.12)
                      : Colors.transparent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$num',
                    style: _codeBaseStyle.copyWith(
                      fontSize: 12,
                      color: isError ? AppTheme.red : AppTheme.comment,
                      fontWeight: isError ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildStatusBar() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    final isValid = _result.isValid;

    return Container(
      height:  28,
      color:   AppTheme.currentLine,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Indicador de estado
          Icon(
            isEmpty  ? Icons.edit_outlined
                : isValid ? Icons.check_circle_outline
                : Icons.error_outline,
            size:  13,
            color: isEmpty  ? AppTheme.comment
                : isValid ? AppTheme.green
                : AppTheme.red,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isEmpty
                  ? 'Listo para programar...'
                  : isValid
                  ? '✓  Sin errores — listo para ejecutar'
                  : '✗  Error${_result.errorLine != null ? ' en línea ${_result.errorLine}' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: isEmpty  ? AppTheme.comment
                    : isValid ? AppTheme.green
                    : AppTheme.red,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Leyenda de colores
          _buildLegend(),
          const SizedBox(width: 12),
          // Contador de líneas
          Text(
            '${widget.controller.text.split('\n').length} L',
            style: const TextStyle(fontSize: 11, color: AppTheme.comment),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    const items = [
      ('KW', AppTheme.pink),
      ('CMD', AppTheme.cyan),
      ('TRIG', AppTheme.orange),
      ('BOOL', AppTheme.purple),
      ('NUM', AppTheme.purple),
      ('VAR', AppTheme.green),
      ('STR', AppTheme.yellow),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((it) {
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: it.$2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              Text(it.$1,
                  style: TextStyle(
                    fontSize: 9, 
                    color: it.$2, 
                    fontFamily: AppTheme.codeStyle.fontFamily,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Barra de sugerencias ─────────────────────────────────────────────────

  Widget _buildSuggestionBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.currentLine,
        border: Border(bottom: BorderSide(color: AppTheme.cyan.withValues(alpha: 0.3))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        itemCount: _sugerencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = _sugerencias[i];
          // Color del chip según categoría
          final kind = _classifyToken(s.split(' ').first);
          final chipColor = _colorFor(kind);
          return GestureDetector(
            onTap: () => _aplicarSugerencia(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:        chipColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: chipColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_tab, size: 12, color: chipColor),
                  const SizedBox(width: 5),
                  Text(
                    s,
                    style: TextStyle(
                      color:      chipColor,
                      fontFamily: AppTheme.codeStyle.fontFamily,
                      fontSize:   12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Banner de error ──────────────────────────────────────────────────────

  Widget _buildErrorBanner(String message) {
    String display = message
        .replaceAll('❌ Error Léxico: ', '')
        .replaceAll('❌ Error Sintáctico: ', '');

    if (display.length > 220) {
      display = '${display.substring(0, 220)}...';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: AppTheme.red,
            width: 4,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                color: AppTheme.red,
                fontSize: 13,
                fontFamily: AppTheme.codeStyle.fontFamily,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
