import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class CommandCreatorScreen extends StatefulWidget {
  const CommandCreatorScreen({super.key});

  @override
  State<CommandCreatorScreen> createState() => _CommandCreatorScreenState();
}

class _CommandCreatorScreenState extends State<CommandCreatorScreen> {
  final _keywordController = TextEditingController();
  final _descController = TextEditingController();
  final _scriptController = TextEditingController();
  final _db = DatabaseService();
  bool _isSaving = false;

  @override
  void dispose() {
    _keywordController.dispose();
    _descController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _saveCommand() async {
    if (_keywordController.text.isEmpty || _scriptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y Script son obligatorios')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _db.saveCustomCommand(
        keyword: _keywordController.text,
        description: _descController.text,
        script: _scriptController.text,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Creador de Comandos (Admin)',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.currentLine,
      ),
      body: ResponsiveCenter(
        maxWidth: r.maxFormWidth + 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nombre del Comando:', style: TextStyle(color: AppTheme.purple, fontWeight: FontWeight.bold)),
            TextField(
              controller: _keywordController,
              style: const TextStyle(color: AppTheme.foreground),
              decoration: const InputDecoration(hintText: 'Ej: CUADRADO', hintStyle: TextStyle(color: AppTheme.comment)),
            ),
            SizedBox(height: r.verticalPadding),
            const Text('Descripción:', style: TextStyle(color: AppTheme.cyan)),
            TextField(
              controller: _descController,
              style: const TextStyle(color: AppTheme.foreground),
              decoration: const InputDecoration(hintText: 'Dibuja un cuadrado de 5x5'),
            ),
            SizedBox(height: r.verticalPadding),
            const Text('Script de ejecución:', style: TextStyle(color: AppTheme.green)),
            const Text('(Comandos básicos separados por líneas)', style: TextStyle(color: AppTheme.comment, fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _scriptController,
              maxLines: r.isCompact ? 6 : 8,
              style: AppTheme.codeStyle.copyWith(
                color: AppTheme.yellow,
                fontSize: r.codeFontSize,
              ),
              decoration: const InputDecoration(
                fillColor: AppTheme.currentLine,
                hintText: 'AVANZAR 5\nGIRAR 90\nAVANZAR 5...',
              ),
            ),
            SizedBox(height: r.verticalPadding * 1.5),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveCommand,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('GUARDAR MACRO-COMANDO'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
