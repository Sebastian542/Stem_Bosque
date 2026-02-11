import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../compiler/lexer/lexer.dart';
import '../../compiler/parser/parser.dart';
import '../../compiler/semantic/semantic_analyzer.dart';
import '../../compiler/executor/program_executor.dart';
import '../../compiler/executor/instruction.dart';
import '../../robot/robot.dart';
import '../../utils/file_utils.dart';

import '../widgets/code_editor.dart';
import '../widgets/console_output.dart';
import '../widgets/robot_canvas.dart';
import '../widgets/toolbar.dart';
import '../theme/app_theme.dart';

/// Pantalla principal del IDE de StemBosque
class IDEScreen extends StatefulWidget {
  const IDEScreen({Key? key}) : super(key: key);

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  // Controladores
  final TextEditingController _codeController = TextEditingController();
  
  // Estado
  final List<LogMessage> _consoleMessages = [];
  late Robot _robot;
  bool _isRunning = false;
  
  // Layout
  double _verticalSplitRatio = 0.5;
  double _horizontalSplitRatio = 0.7;

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
    _robot = Robot(x: 430, y: 285);
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
            isRunning: _isRunning,
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: (_verticalSplitRatio * 100).toInt(),
                  child: Column(
                    children: [
                      Expanded(
                        flex: (_horizontalSplitRatio * 100).toInt(),
                        child: AdvancedCodeEditor(
                          controller: _codeController,
                        ),
                      ),
                      _buildHorizontalDivider(),
                      Expanded(
                        flex: ((1 - _horizontalSplitRatio) * 100).toInt(),
                        child: ConsoleOutput(
                          messages: _consoleMessages,
                          onClear: _clearConsole,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildVerticalDivider(),
                Expanded(
                  flex: ((1 - _verticalSplitRatio) * 100).toInt(),
                  child: Center(
                    child: SizedBox(
                      width: 860,
                      height: 570,
                      child: RobotCanvas(
                        robot: _robot,
                        showGrid: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            final width = MediaQuery.of(context).size.width;
            _verticalSplitRatio = (_verticalSplitRatio + details.delta.dx / width)
                .clamp(0.2, 0.8);
          });
        },
        child: Container(
          width: 8,
          color: AppTheme.currentLine,
          child: Center(
            child: Container(
              width: 2,
              color: AppTheme.comment,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDivider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            final height = MediaQuery.of(context).size.height;
            _horizontalSplitRatio = (_horizontalSplitRatio + details.delta.dy / height)
                .clamp(0.3, 0.9);
          });
        },
        child: Container(
          height: 6,
          color: AppTheme.currentLine,
          child: Center(
            child: Container(
              height: 2,
              color: AppTheme.comment,
            ),
          ),
        ),
      ),
    );
  }

  // === MÉTODOS DE ACCIÓN ===

  Future<void> _executeProgram() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _consoleMessages.clear();
    });

    _addLog('Iniciando compilación...', LogType.info);

    try {
      // 1. Análisis léxico
      final lexer = Lexer(_codeController.text);
      final tokens = lexer.tokenize();
      _addLog('✓ Análisis léxico completado (${tokens.length} tokens)', LogType.success);

      // 2. Análisis sintáctico
      final parser = Parser(tokens);
      final ast = parser.parse();
      _addLog('✓ Análisis sintáctico completado', LogType.success);
      _addLog('  Programa: "${ast.nombre}"', LogType.info);

      // 3. Análisis semántico
      final analyzer = SemanticAnalyzer();
      final isValid = analyzer.analyze(ast);
      
      if (!isValid) {
        _addLog('✗ Errores semánticos:', LogType.error);
        for (final error in analyzer.errors) {
          _addLog('  $error', LogType.error);
        }
        setState(() => _isRunning = false);
        return;
      }
      _addLog('✓ Análisis semántico completado', LogType.success);

      // 4. Ejecución
      final executor = ProgramExecutor();
      final instructions = executor.execute(ast);
      _addLog('✓ Programa compilado (${instructions.length} instrucciones)', LogType.success);

      // 5. Reiniciar robot
      _robot.reset(860, 570);
      setState(() {});

      // 6. Ejecutar instrucciones con animación
      _addLog('Ejecutando programa...', LogType.info);
      await _executeInstructions(instructions);
      
      _addLog('✓ Programa ejecutado exitosamente', LogType.success);
      
    } catch (e) {
      _addLog('✗ Error: $e', LogType.error);
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _executeInstructions(List<Instruction> instructions) async {
    for (final instruction in instructions) {
      _addLog('  → ${instruction.toString()}', LogType.info);
      
      switch (instruction.type) {
        case InstructionType.avanzar:
          final repetir = instruction.value.abs();
          final dir = instruction.value >= 0 ? 1 : -1;
          
          for (int i = 0; i < repetir; i++) {
            _robot.avanzar(dir);
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 100));
          }
          break;
          
        case InstructionType.girar:
          final repetir = instruction.value.abs();
          final dir = instruction.value >= 0 ? 1 : -1;
          
          for (int i = 0; i < repetir; i++) {
            _robot.girar(dir);
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 100));
          }
          break;
          
        case InstructionType.asignar:
          // Las asignaciones ya fueron procesadas
          break;
      }
    }
  }

  void _clearCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar código'),
        content: const Text('¿Está seguro de que desea limpiar todo el código?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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
        _addLog('Archivo abierto exitosamente', LogType.success);
      }
    } catch (e) {
      _addLog('Error al abrir archivo: $e', LogType.error);
    }
  }

  Future<void> _saveFile() async {
    try {
      final saved = await FileUtils.saveFile(_codeController.text);
      if (saved) {
        _addLog('Archivo guardado exitosamente', LogType.success);
      }
    } catch (e) {
      _addLog('Error al guardar archivo: $e', LogType.error);
    }
  }

  void _clearConsole() {
    setState(() {
      _consoleMessages.clear();
      _addLog('Consola limpiada', LogType.info);
    });
  }

  void _addLog(String message, LogType type) {
    setState(() {
      _consoleMessages.add(LogMessage(
        message: message,
        type: type,
      ));
    });
  }
}
