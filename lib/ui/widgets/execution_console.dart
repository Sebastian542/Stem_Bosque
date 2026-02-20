import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ExecutionConsole extends StatefulWidget {
  final List<String> lines;
  final bool         isSuccess;
  final String?      errorMessage;
  final VoidCallback onSend;
  final VoidCallback onClose;

  const ExecutionConsole({
    Key? key,
    required this.lines,
    required this.isSuccess,
    this.errorMessage,
    required this.onSend,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ExecutionConsole> createState() => _ExecutionConsoleState();
}

class _ExecutionConsoleState extends State<ExecutionConsole>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(
      begin: const Offset(1, 0), // entra desde la derecha (pantalla completa)
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.currentLine,
      child: Row(
        children: [
          Icon(
            widget.isSuccess ? Icons.terminal : Icons.error_outline,
            color: widget.isSuccess ? AppTheme.green : AppTheme.red,
            size: 22,
          ),
          const SizedBox(width: 12),
          Text(
            widget.isSuccess ? 'Ejecución completada' : 'Error de compilación',
            style: TextStyle(
              color:      widget.isSuccess ? AppTheme.green : AppTheme.red,
              fontWeight: FontWeight.bold,
              fontSize:   15,
            ),
          ),
          const Spacer(),
          // Botón volver al editor
          TextButton.icon(
            onPressed: widget.onClose,
            icon:  const Icon(Icons.arrow_back, size: 16),
            label: const Text('Volver al editor'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.comment),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // ── Error ────────────────────────────────────────────────
    if (!widget.isSuccess && widget.errorMessage != null) {
      final clean = widget.errorMessage!
          .replaceAll('❌ Error Léxico: ', '')
          .replaceAll('❌ Error Sintáctico: ', '');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bug_report, color: AppTheme.red, size: 48),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        AppTheme.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: AppTheme.red.withOpacity(0.4)),
                ),
                child: Text(
                  clean,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize:   13,
                    color:      AppTheme.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Salida del intérprete ────────────────────────────────
    return Container(
      color: AppTheme.background,
      child: ListView.builder(
        padding:     const EdgeInsets.all(16),
        itemCount:   widget.lines.length,
        itemBuilder: (_, i) {
          final line  = widget.lines[i];
          Color color = AppTheme.foreground;
          if (line.startsWith('▶') || line.startsWith('■')) {
            color = AppTheme.cyan;
          } else if (line.startsWith('GIRAR') || line.startsWith('AVANZAR')) {
            color = AppTheme.green;
          } else if (line.contains('=')) {
            color = AppTheme.purple;
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Text('> ', style: TextStyle(
                    color: AppTheme.comment, fontFamily: 'monospace', fontSize: 13)),
                Expanded(
                  child: Text(line, style: TextStyle(
                      fontFamily: 'monospace', fontSize: 13, color: color)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color:  AppTheme.currentLine,
        border: Border(top: BorderSide(color: AppTheme.comment, width: 1)),
      ),
      child: widget.isSuccess
          ? Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.green, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Programa ejecutado exitosamente. ¿Desea enviarlo?',
              style: TextStyle(color: AppTheme.green, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: widget.onSend,
            icon:  const Icon(Icons.send, size: 18),
            label: const Text('Enviar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
          ),
        ],
      )
          : Row(
        children: [
          const Icon(Icons.cancel, color: AppTheme.red, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No se puede enviar mientras haya errores.',
              style: TextStyle(color: AppTheme.red, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: widget.onClose,
            child: const Text('Volver',
                style: TextStyle(color: AppTheme.comment)),
          ),
        ],
      ),
    );
  }
}