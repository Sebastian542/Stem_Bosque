import 'dart:async';
import 'package:flutter/material.dart';

import '../../compiler/lexer/lexer.dart';
import '../../compiler/parser/parser.dart';
import '../../compiler/semantic/semantic_analyzer.dart';
import '../../compiler/executor/program_executor.dart';
import '../../compiler/executor/instruction.dart';
import '../../utils/file_utils.dart';

import '../widgets/code_editor.dart';
import '../widgets/console_output.dart';
import '../widgets/toolbar.dart';
import '../widgets/bluetooth_panel.dart';
import '../theme/app_theme.dart';

class IDEScreen extends StatefulWidget {
  const IDEScreen({Key? key}) : super(key: key);

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  final TextEditingController _codeController = TextEditingController();
  final List<LogMessage> _consoleMessages = [];
  bool _isRunning = false;
  bool _showBluetoothPanel = false;

  // Ratio editor/consola (arrastrable)
  double _splitRatio = 0.72;

  static const String _sampleCode = '''/*Un sencillo programa de ejemplo.*/
PROGRAMA "Programa numero 1"

  /*Comandos básicos*/
  AVANZAR 5
  AVANZAR -5
  GIRAR 5
  GIRAR -5

  /*Variables*/
  N=100
  Contador = 1
  
  /*Uso de ciclos*/
  REPETIR [N] VECES: 
    GIRAR 1 
  FIN REPETIR

  /*Uso de condicionales*/
  SI N<200 ENTONCES: 
    REPETIR [N] VECES: 
      GIRAR -1 
    FIN REPETIR
  FIN SI

FIN PROGRAMA''';

  @override
  void initState() {
    super.initState();
    _codeController.text = _sampleCode;
    _addLog('Esperando ejecución...', LogType.info);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StemBosque IDE'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Toolbar(
            onRun: _executeProgram,
            onClear: _clearCode,
            onOpen: _openFile,
            onSave: _saveFile,
            onBluetooth: _toggleBluetoothPanel,
            isRunning: _isRunning,
            isBluetoothOpen: _showBluetoothPanel,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Editor + Consola ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      // Editor
                      Expanded(
                        flex: (_splitRatio * 1000).toInt(),
                        child: AdvancedCodeEditor(
                          controller: _codeController,
                        ),
                      ),
                      // Divisor arrastrable
                      _buildDivider(),
                      // Consola
                      Expanded(
                        flex: ((1 - _splitRatio) * 1000).toInt(),
                        child: ConsoleOutput(
                          messages: _consoleMessages,
                          onClear: _clearConsole,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Panel Bluetooth ───────────────────────────────────────────
                if (_showBluetoothPanel)
                  BluetoothPanel(
                    codeContent: _codeController.text,
                    onLog: (msg, isError) => _addLog(
                      msg,
                      isError ? LogType.error : LogType.success,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragUpdate: (d) {
          setState(() {
            final h = MediaQuery.of(context).size.height;
            _splitRatio = (_splitRatio + d.delta.dy / h).clamp(0.25, 0.90);
          });
        },
        child: Container(
          height: 6,
          color: AppTheme.currentLine,
          child: Center(
            child: Container(height: 2, color: AppTheme.comment),
          ),
        ),
      ),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────────

  Future<void> _executeProgram() async {
    if (_isRunning) return;
    setState(() { _isRunning = true; _consoleMessages.clear(); });
    _addLog('Iniciando compilación...', LogType.info);

    try {
      final lexer  = Lexer(_codeController.text);
      final tokens = lexer.tokenize();
      _addLog('✓ Análisis léxico (${tokens.length} tokens)', LogType.success);

      final parser = Parser(tokens);
      final ast    = parser.parse();
      _addLog('✓ Análisis sintáctico — "${ast.nombre}"', LogType.success);

      final analyzer = SemanticAnalyzer();
      if (!analyzer.analyze(ast)) {
        for (final e in analyzer.errors) _addLog('  ✗ $e', LogType.error);
        setState(() => _isRunning = false);
        return;
      }
      _addLog('✓ Análisis semántico', LogType.success);

      final executor     = ProgramExecutor();
      final instructions = executor.execute(ast);
      _addLog('✓ Compilado — ${instructions.length} instrucciones', LogType.success);

      await _runInstructions(instructions);
      _addLog('✓ Ejecución completada', LogType.success);
    } catch (e) {
      _addLog('✗ $e', LogType.error);
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _runInstructions(List<Instruction> instructions) async {
    for (final ins in instructions) {
      _addLog('  → $ins', LogType.info);
      final reps = ins.value.abs();
      final dir  = ins.value >= 0 ? 1 : -1;
      if (ins.type == InstructionType.avanzar ||
          ins.type == InstructionType.girar) {
        for (int i = 0; i < reps; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }
  }

  void _clearCode() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpiar código'),
        content: const Text('¿Deseas limpiar todo el código?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              _codeController.clear();
              Navigator.pop(context);
              _addLog('Código limpiado', LogType.info);
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile() async {
    try {
      final content = await FileUtils.openFile();
      if (content != null) {
        _codeController.text = content;
        _addLog('Archivo abierto', LogType.success);
      }
    } catch (e) { _addLog('Error: $e', LogType.error); }
  }

  Future<void> _saveFile() async {
    try {
      if (await FileUtils.saveFile(_codeController.text)) {
        _addLog('Archivo guardado', LogType.success);
      }
    } catch (e) { _addLog('Error: $e', LogType.error); }
  }

  void _clearConsole() => setState(() {
    _consoleMessages.clear();
    _addLog('Consola limpiada', LogType.info);
  });

  void _toggleBluetoothPanel() {
    setState(() => _showBluetoothPanel = !_showBluetoothPanel);
    _addLog(
      _showBluetoothPanel ? 'Bluetooth abierto' : 'Bluetooth cerrado',
      LogType.info,
    );
  }

  void _addLog(String message, LogType type) => setState(() {
    _consoleMessages.add(LogMessage(message: message, type: type));
  });
}
