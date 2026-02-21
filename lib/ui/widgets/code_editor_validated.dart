import 'package:flutter/material.dart';
import '../../compiler/syntax_validator.dart';
import '../theme/app_theme.dart';

const _palabrasClave = [
  'PROGRAMA',
  'FIN PROGRAMA',
  'FIN REPETIR',
  'FIN SI',
  'AVANZAR',
  'GIRAR',
  'REPETIR',
  'VECES',
  'SI',
  'ENTONCES',
  'FIN',
];

class ValidatedCodeEditor extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool> onValidityChanged;

  const ValidatedCodeEditor({
    Key? key,
    required this.controller,
    required this.onValidityChanged,
  }) : super(key: key);

  @override
  State<ValidatedCodeEditor> createState() => _ValidatedCodeEditorState();
}

class _ValidatedCodeEditorState extends State<ValidatedCodeEditor> {
  final _validator        = SyntaxValidator();
  final _focusNode        = FocusNode();
  final _scrollController = ScrollController();
  final _lineScrollCtrl   = ScrollController();

  ValidationResult _result     = const ValidationResult.valid();
  List<String>     _sugerencias = [];

  static const _fontSize   = 14.0;
  static const _lineHeight = 1.5;
  static const _fontFamily = 'monospace';

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
    final text      = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) {
      setState(() => _sugerencias = []);
      return;
    }

    final textHastaCursor = text.substring(0, cursorPos);
    final match = RegExp(r'[A-Za-z_]+$').firstMatch(textHastaCursor);
    if (match == null) {
      setState(() => _sugerencias = []);
      return;
    }

    final palabraActual = match.group(0)!.toUpperCase();
    if (palabraActual.length < 2) {
      setState(() => _sugerencias = []);
      return;
    }

    final sugerencias = _palabrasClave
        .where((k) =>
    k.startsWith(palabraActual) &&
        k != palabraActual)
        .toList();

    setState(() => _sugerencias = sugerencias);
  }

  void _aplicarSugerencia(String sugerencia) {
    final text      = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;
    if (cursorPos < 0) return;

    int inicio = cursorPos - 1;
    while (inicio >= 0 &&
        text[inicio] != ' ' &&
        text[inicio] != '\n') {
      inicio--;
    }
    inicio++;

    final nuevoTexto =
        text.substring(0, inicio) +
            sugerencia +
            text.substring(cursorPos);

    final nuevoCursor = inicio + sugerencia.length;

    widget.controller.value = TextEditingValue(
      text:      nuevoTexto,
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
    final lines = widget.controller.text.split('\n');

    return Column(
      children: [
        _buildStatusBar(),
        if (_sugerencias.isNotEmpty) _buildSuggestionBar(),
        Expanded(
          child: Container(
            color: AppTheme.background,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLineNumbers(lines, _result.errorLine),
                Expanded(child: _buildTextField()),
              ],
            ),
          ),
        ),
        if (!_result.isValid && _result.errorMessage != null)
          _buildErrorBanner(_result.errorMessage!),
      ],
    );
  }

  Widget _buildSuggestionBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.currentLine,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        itemCount: _sugerencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = _sugerencias[i];
          return GestureDetector(
            onTap: () => _aplicarSugerencia(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:        AppTheme.cyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: AppTheme.cyan.withOpacity(0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.keyboard_tab,
                      size: 13, color: AppTheme.cyan),
                  const SizedBox(width: 5),
                  Text(
                    s,
                    style: const TextStyle(
                      color:      AppTheme.cyan,
                      fontFamily: _fontFamily,
                      fontSize:   13,
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

  Widget _buildTextField() {
    return TextField(
      controller:       widget.controller,
      focusNode:        _focusNode,
      scrollController: _scrollController,
      maxLines:         null,
      expands:          true,
      style: const TextStyle(
        fontFamily: _fontFamily,
        fontSize:   _fontSize,
        height:     _lineHeight,
        color:      AppTheme.foreground,
      ),
      decoration: const InputDecoration(
        border:         InputBorder.none,
        contentPadding: EdgeInsets.only(left: 8, top: 8),
        isCollapsed:    true,
      ),
      cursorColor:  AppTheme.cyan,
      cursorWidth:  2,
      keyboardType: TextInputType.multiline,
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
          const SizedBox(width: 8),
          Text(
            '${widget.controller.text.split('\n').length}L',
            style: const TextStyle(fontSize: 11, color: AppTheme.comment),
          ),
        ],
      ),
    );
  }

  Widget _buildLineNumbers(List<String> lines, int? errorLine) {
    return Container(
      width: 44,
      color: AppTheme.currentLine,
      child: ListView.builder(
        controller:  _lineScrollCtrl,
        physics:     const NeverScrollableScrollPhysics(),
        padding:     const EdgeInsets.only(top: 8),
        itemCount:   lines.length,
        itemBuilder: (_, i) {
          final num     = i + 1;
          final isError = errorLine != null && num == errorLine;
          return SizedBox(
            height: _fontSize * _lineHeight,
            child: Center(
              child: Text(
                '$num',
                style: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize:   12,
                  color:      isError ? AppTheme.red : AppTheme.comment,
                  fontWeight: isError ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    String display = message
        .replaceAll('❌ Error Léxico: ', '')
        .replaceAll('❌ Error Sintáctico: ', '');
    if (display.length > 220) display = '${display.substring(0, 220)}...';

    return Container(
      color:   AppTheme.red.withOpacity(0.10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(
                color:      AppTheme.red,
                fontSize:   12,
                fontFamily: _fontFamily,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final int?   errorLine;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;

  const _HighlightedText({
    required this.text,
    required this.errorLine,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    if (errorLine == null) {
      return Text(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize:   fontSize,
          height:     lineHeight,
          color:      AppTheme.foreground,
        ),
      );
    }

    final lines  = text.split('\n');
    final spans  = <TextSpan>[];
    final errIdx = errorLine! - 1;

    for (int i = 0; i < lines.length; i++) {
      final lineText = i < lines.length - 1 ? '${lines[i]}\n' : lines[i];
      if (i == errIdx) {
        spans.add(TextSpan(
          text: lineText,
          style: TextStyle(
            fontFamily:          fontFamily,
            fontSize:            fontSize,
            height:              lineHeight,
            color:               AppTheme.red,
            decoration:          TextDecoration.underline,
            decorationColor:     AppTheme.red,
            decorationStyle:     TextDecorationStyle.wavy,
            decorationThickness: 2,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: lineText,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize:   fontSize,
            height:     lineHeight,
            color:      AppTheme.foreground,
          ),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }
}