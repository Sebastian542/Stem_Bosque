import 'package:flutter/material.dart';
import '../../compiler/syntax_validator.dart';
import '../theme/app_theme.dart';

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
  final _validator      = SyntaxValidator();
  final _focusNode      = FocusNode();
  final _lineScrollCtrl = ScrollController(); // SOLO para números de línea

  ValidationResult _result = const ValidationResult.valid();
  double _currentScrollOffset = 0;

  static const _fontSize   = 14.0;
  static const _lineHeight = 1.5;
  static const _fontFamily = 'monospace';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _lineScrollCtrl.dispose();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    // Tiempo real — sin debounce
    final result = _validator.validate(widget.controller.text);
    if (mounted) {
      setState(() => _result = result);
      widget.onValidityChanged(result.isValid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.controller.text.split('\n');

    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: Container(
            color: AppTheme.background,
            // NotificationListener captura el scroll del TextField
            // sin necesidad de compartir ScrollController
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  final offset = notification.metrics.pixels;
                  setState(() => _currentScrollOffset = offset);
                  if (_lineScrollCtrl.hasClients) {
                    _lineScrollCtrl.jumpTo(offset);
                  }
                }
                return false;
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLineNumbers(lines, _result.errorLine),
                  Expanded(child: _buildTextField()),
                ],
              ),
            ),
          ),
        ),
        if (!_result.isValid && _result.errorMessage != null)
          _buildErrorBanner(_result.errorMessage!),
      ],
    );
  }

  Widget _buildTextField() {
    return Stack(
      children: [
        // ── Capa de resaltado (RichText) — no tiene ScrollController ──
        Positioned.fill(
          child: SingleChildScrollView(
            // Sin controller propio — se sincroniza via offset
            physics: const NeverScrollableScrollPhysics(),
            child: Transform.translate(
              offset: Offset(0, -_currentScrollOffset),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: _HighlightedText(
                  text:       widget.controller.text,
                  errorLine:  _result.errorLine,
                  fontSize:   _fontSize,
                  lineHeight: _lineHeight,
                  fontFamily: _fontFamily,
                ),
              ),
            ),
          ),
        ),

        // ── TextField real (maneja su propio scroll) ─────────────────
        TextField(
          controller:  widget.controller,
          focusNode:   _focusNode,
          // ← SIN scrollController — usa el suyo interno
          maxLines:    null,
          expands:     true,
          style: const TextStyle(
            fontFamily: _fontFamily,
            fontSize:   _fontSize,
            height:     _lineHeight,
            color:      Colors.transparent, // texto invisible, lo pinta RichText
          ),
          decoration: const InputDecoration(
            border:         InputBorder.none,
            contentPadding: EdgeInsets.only(left: 8, top: 8),
            isCollapsed:    true,
          ),
          cursorColor: AppTheme.cyan,
          keyboardType: TextInputType.multiline,
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    final isEmpty = widget.controller.text.trim().isEmpty;
    final isValid = _result.isValid;

    return Container(
      height: 28,
      color:  AppTheme.currentLine,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // ← Wrap en Row con Flexible para evitar overflow
      child: Row(
        children: [
          Icon(
            isEmpty  ? Icons.edit_outlined
                : isValid ? Icons.check_circle
                : Icons.error_outline,
            size: 14,
            color: isEmpty  ? AppTheme.comment
                : isValid ? AppTheme.green
                : AppTheme.red,
          ),
          const SizedBox(width: 6),
          Flexible( // ← Flexible evita el overflow de 32px
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
              overflow: TextOverflow.ellipsis, // ← corta si no cabe
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
                  fontFamily:  _fontFamily,
                  fontSize:    12,
                  color:       isError ? AppTheme.red : AppTheme.comment,
                  fontWeight:  isError ? FontWeight.bold : FontWeight.normal,
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
    if (display.length > 130) display = '${display.substring(0, 130)}...';

    return Container(
      color:   AppTheme.red.withOpacity(0.10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── RichText con subrayado wavy en la línea de error ─────────────────

class _HighlightedText extends StatelessWidget {
  final String  text;
  final int?    errorLine;
  final double  fontSize;
  final double  lineHeight;
  final String  fontFamily;

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
            fontFamily:       fontFamily,
            fontSize:         fontSize,
            height:           lineHeight,
            color:            AppTheme.red,
            decoration:       TextDecoration.underline,
            decorationColor:  AppTheme.red,
            decorationStyle:  TextDecorationStyle.wavy,
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