import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Editor de código simple sin dependencias externas
class CodeEditor extends StatefulWidget {
  final TextEditingController controller;
  final String? initialCode;

  const CodeEditor({
    Key? key,
    required this.controller,
    this.initialCode,
  }) : super(key: key);

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      widget.controller.text = widget.initialCode!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: TextField(
        controller: widget.controller,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 16,
          color: AppTheme.foreground,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
          hintText: 'Escribe tu código aquí...',
          hintStyle: TextStyle(color: AppTheme.comment),
        ),
        textAlignVertical: TextAlignVertical.top,
      ),
    );
  }
}

/// Editor de código avanzado con números de línea
class AdvancedCodeEditor extends StatefulWidget {
  final TextEditingController controller;
  final String? initialCode;

  const AdvancedCodeEditor({
    Key? key,
    required this.controller,
    this.initialCode,
  }) : super(key: key);

  @override
  State<AdvancedCodeEditor> createState() => _AdvancedCodeEditorState();
}

class _AdvancedCodeEditorState extends State<AdvancedCodeEditor> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _lineNumberScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      widget.controller.text = widget.initialCode!;
    }
    
    // Sincronizar scroll de números de línea con el editor
    _scrollController.addListener(() {
      if (_lineNumberScrollController.hasClients) {
        _lineNumberScrollController.jumpTo(_scrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _lineNumberScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Números de línea
          _buildLineNumbers(),
          
          // Separador
          Container(
            width: 1,
            color: AppTheme.currentLine,
          ),
          
          // Editor
          Expanded(
            child: TextField(
              controller: widget.controller,
              scrollController: _scrollController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                color: AppTheme.foreground,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                hintText: 'Escribe tu código aquí...',
                hintStyle: TextStyle(color: AppTheme.comment),
              ),
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineNumbers() {
    return Container(
      width: 50,
      color: AppTheme.background,
      child: SingleChildScrollView(
        controller: _lineNumberScrollController,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, child) {
              final lineCount = '\n'.allMatches(value.text).length + 1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  lineCount,
                  (index) => SizedBox(
                    height: 24, // Altura de línea = fontSize * height (16 * 1.5)
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        color: AppTheme.comment,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
