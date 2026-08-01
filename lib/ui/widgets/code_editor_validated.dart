import 'package:flutter/material.dart';
import '../../compiler/syntax_validator.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

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

List<_Token> _tokenizeLine(String line, List<String> customCommands) {
  final commentIdx = line.indexOf('//');
  final code    = commentIdx >= 0 ? line.substring(0, commentIdx) : line;
  final comment = commentIdx >= 0 ? line.substring(commentIdx) : null;

  final tokens = <_Token>[];
  // Regex para strings, números, identificadores, espacios y otros caracteres
  final re = RegExp(r'"[^"]*"|[0-9]+(?:\.[0-9]+)?|[A-Za-z_][A-Za-z0-9_]*|[^\s]|\s+');

  for (final m in re.allMatches(code)) {
    final t = m.group(0)!;
    tokens.add(_Token(t, _classifyToken(t, customCommands)));
  }
  if (comment != null) tokens.add(_Token(comment, _TokenKind.comment));
  return tokens;
}

_TokenKind _classifyToken(String t, List<String> customCommands) {
  if (t.trim().isEmpty) return _TokenKind.other;

  const structureKw = {'PROGRAMA', 'FIN', 'SI', 'ENTONCES', 'REPETIR', 'VECES'};
  const commandKw   = {'GIRAR', 'AVANZAR'};
  const trigKw      = {'SEN', 'COS', 'TANG'};
  const boolKw      = {'AND', 'OR', 'NOT'};
  final up = t.toUpperCase();

  if (t.startsWith('"')) return _TokenKind.string;
  if (RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(t)) return _TokenKind.number;
  if (structureKw.contains(up)) return _TokenKind.keyword;
  if (commandKw.contains(up) || customCommands.contains(up)) return _TokenKind.command;
  if (trigKw.contains(up))      return _TokenKind.trig;
  if (boolKw.contains(up))      return _TokenKind.boolean;
  if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(t)) return _TokenKind.identifier;
  
  return _TokenKind.other;
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
// CONTROLADOR CON RESALTADO DE SINTAXIS
// ═══════════════════════════════════════════════════════════════════════════

class CodeEditorController extends TextEditingController {
  List<String> customCommands = [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final lines = text.split('\n');
    final children = <TextSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final tks = _tokenizeLine(lines[i], customCommands);
      children.add(TextSpan(
        children: tks.map((tk) {
          final isBold = tk.kind == _TokenKind.keyword || 
                         tk.kind == _TokenKind.command || 
                         tk.kind == _TokenKind.boolean || 
                         tk.kind == _TokenKind.trig;
          return TextSpan(
            text: tk.text,
            style: TextStyle(
              color: _colorFor(tk.kind),
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          );
        }).toList(),
      ));
      if (i < lines.length - 1) children.add(const TextSpan(text: '\n'));
    }

    return TextSpan(style: style, children: children);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class ValidatedCodeEditor extends StatefulWidget {
  final CodeEditorController controller;
  final List<String> customCommands;
  final void Function(bool isValid, String? errorMessage) onValidityChanged;

  const ValidatedCodeEditor({
    super.key,
    required this.controller,
    this.customCommands = const [],
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

  double _fontSize = 14.0;
  double _fontSizeOnScaleStart = 14.0;
  bool _fontSizeInitialized = false;
  static const double _minFontSize = 9.0;
  static const double _maxFontSize = 28.0;
  static const double _lineHeight = 1.5;
  double get _lineH => _fontSize * _lineHeight;

  static const _fontFamily = 'monospace';
  static const _padding = 8.0;

  @override
  void initState() {
    super.initState();
    _updateControllerCommands();
    widget.controller.addListener(_onTextChanged);
    _scrollController.addListener(_syncLineScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onTextChanged();
    });
  }

  @override
  void didUpdateWidget(ValidatedCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _updateControllerCommands();
      _onTextChanged();
    } else if (oldWidget.customCommands != widget.customCommands) {
      _updateControllerCommands();
      _onTextChanged();
    }
  }

  void _updateControllerCommands() {
    widget.controller.customCommands = 
        widget.customCommands.map((c) => c.toUpperCase()).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fontSizeInitialized) {
      _fontSize = context.responsive.codeFontSize;
      _fontSizeInitialized = true;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    _lineScrollCtrl.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  void _onTextChanged() {
    final result = _validator.validate(
      widget.controller.text, 
      comandosPersonalizados: widget.customCommands
    );
    
    if (mounted) {
      setState(() => _result = result);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onValidityChanged(
            result.isValid,
            result.isValid ? null : result.errorMessage,
          );
        }
      });
    }
    _actualizarSugerencias();
  }

  void _actualizarSugerencias() {
    final text      = widget.controller.text;
    final selection = widget.controller.selection;
    final cursorPos = selection.baseOffset;
    
    if (cursorPos < 0 || cursorPos > text.length) {
      if (_sugerencias.isNotEmpty) setState(() => _sugerencias = []);
      return;
    }
    
    final textHastaCursor = text.substring(0, cursorPos);
    final match = RegExp(r'[A-Za-z0-9_]+$').firstMatch(textHastaCursor);
    
    if (match == null || match.group(0)!.length < 2) {
      if (_sugerencias.isNotEmpty) setState(() => _sugerencias = []);
      return;
    }
    
    final palabraActual = match.group(0)!.toUpperCase();
    final todasLasPalabras = {
      'PROGRAMA', 'FIN PROGRAMA', 'FIN REPETIR', 'FIN SI',
      'AVANZAR', 'GIRAR', 'REPETIR', 'VECES', 'SI', 'ENTONCES', 'FIN',
      'AND', 'OR', 'NOT', 'SEN', 'COS', 'TANG',
      ...widget.customCommands.map((c) => c.toUpperCase())
    };
    
    final filtradas = todasLasPalabras
        .where((k) => k.startsWith(palabraActual) && k != palabraActual)
        .toList();
    
    if (filtradas.length != _sugerencias.length) {
      setState(() => _sugerencias = filtradas);
    }
  }

  void _aplicarSugerencia(String sugerencia) {
    final text      = widget.controller.text;
    final selection = widget.controller.selection;
    final cursorPos = selection.baseOffset;
    if (cursorPos < 0) return;

    final textHastaCursor = text.substring(0, cursorPos);
    final match = RegExp(r'[A-Za-z0-9_]+$').firstMatch(textHastaCursor);
    if (match == null) return;

    final inicio = match.start;
    final nuevoTexto = text.replaceRange(inicio, cursorPos, sugerencia);
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
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusBar(),
        if (_sugerencias.isNotEmpty) _buildSuggestionBar(),

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
                  Container(width: 1, color: AppTheme.currentLine),
                  Expanded(child: _buildTextField()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField() {
    final minEditorWidth = MediaQuery.sizeOf(context).width * 1.5;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: minEditorWidth.clamp(600, 2000),
        child: TextField(
          controller:       widget.controller,
          focusNode:        _focusNode,
          scrollController: _scrollController,
          maxLines:         null,
          expands:          true,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            fontFamily: _fontFamily,
            fontSize:   _fontSize,
            height:     _lineHeight,
            color:      AppTheme.foreground,
          ),
          decoration: const InputDecoration(
            border:         InputBorder.none,
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
    );
  }

  Widget _buildLineNumbers() {
    final gutter = context.responsive.gutterWidth;

    return SizedBox(
      width: gutter,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final lines = value.text.split('\n');
          final errorLine = _result.errorLine;

          int currentLine = -1;
          if (value.selection.baseOffset >= 0) {
            currentLine = '\n'
                .allMatches(value.text.substring(0, value.selection.baseOffset))
                .length;
          }

          return ListView.builder(
            controller:  _lineScrollCtrl,
            physics:     const NeverScrollableScrollPhysics(),
            padding:     const EdgeInsets.only(top: _padding),
            itemCount:   lines.length,
            itemBuilder: (_, i) {
              final num       = i + 1;
              final isError   = errorLine != null && num == errorLine;
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
                        ? const Border(right: BorderSide(color: AppTheme.cyan, width: 2))
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
                      fontWeight: (isError || isCurrent) ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildStatusBar() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    final isValid = _result.isValid;

    return Container(
      height:  28,
      color:   AppTheme.currentLine,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(
            isEmpty  ? Icons.edit_outlined
                : isValid ? Icons.check_circle
                : Icons.error_outline,
            size:  14,
            color: isEmpty  ? AppTheme.comment
                : isValid ? AppTheme.green
                : AppTheme.red,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isEmpty
                  ? 'Escribe tu programa...'
                  : isValid
                  ? 'Sin errores — listo para ejecutar'
                  : 'Error${_result.errorLine != null ? ' — línea ${_result.errorLine}' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: isEmpty  ? AppTheme.comment
                    : isValid ? AppTheme.green
                    : AppTheme.red,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const Spacer(),
          _buildLegend(),
          const SizedBox(width: 12),
          Text(
            '${_fontSize.round()}px',
            style: const TextStyle(fontSize: 10, color: AppTheme.comment),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.controller.text.split('\n').length}L',
            style: const TextStyle(fontSize: 11, color: AppTheme.comment),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    const items = [
      ('KW',   AppTheme.pink),
      ('CMD',  AppTheme.cyan),
      ('LOG',  AppTheme.purple),
      ('TRIG', AppTheme.orange),
      ('VAR',  AppTheme.green),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((it) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: it.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(it.$1, style: TextStyle(fontSize: 9, color: it.$2, fontWeight: FontWeight.bold)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSuggestionBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.currentLine,
        border: Border(bottom: BorderSide(color: AppTheme.cyan.withValues(alpha: 0.2))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: _sugerencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _sugerencias[i];
          final kind = _classifyToken(s.split(' ').first, widget.customCommands);
          final color = _colorFor(kind);
          return GestureDetector(
            onTap: () => _aplicarSugerencia(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_box_outlined, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(s, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
