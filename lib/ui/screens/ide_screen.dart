import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../compiler/lexer/lexer.dart';
import '../../compiler/parser/parser.dart';
import '../../compiler/semantic/semantic_analyzer.dart';
import '../../compiler/executor/program_executor.dart';
import '../../compiler/executor/instruction.dart';
import '../../robot/robot.dart';
import '../../utils/file_utils.dart';

import '../widgets/code_editor.dart';
import '../widgets/console_output.dart';
import '../widgets/toolbar.dart';
import '../theme/app_theme.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:permission_handler/permission_handler.dart';

import 'package:share_plus/share_plus.dart';

/// Tipo de dispositivo Bluetooth
enum BluetoothDeviceType { ble, classic }

/// Clase unificada para representar dispositivos Bluetooth
class UnifiedBluetoothDevice {
  final String name;
  final String address;
  final BluetoothDeviceType type;
  final int? rssi;

  // Referencias a los objetos originales
  final BluetoothDevice? bleDevice;
  final classic.BluetoothDevice? classicDevice;

  UnifiedBluetoothDevice({
    required this.name,
    required this.address,
    required this.type,
    this.rssi,
    this.bleDevice,
    this.classicDevice,
  });

  String get displayName => name.isNotEmpty ? name : 'Dispositivo (${address.substring(0, 8)}...)';
}

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
  bool _isRunning = false;

  // Bluetooth Unificado
  bool _bluetoothEnabled = false;
  List<UnifiedBluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  UnifiedBluetoothDevice? _connectedDevice;
  bool _showBluetoothPanel = false;

  // Bluetooth BLE
  BluetoothAdapterState _bleState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _bleSubscription;
  StreamSubscription<List<ScanResult>>? _bleScanSubscription;

  // Bluetooth Clásico
  classic.BluetoothConnection? _classicConnection;
  StreamSubscription<classic.BluetoothState>? _classicSubscription;

  // Control de conexión
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  Timer? _connectionTimeoutTimer;

  // Layout
  double _horizontalSplitRatio = 0.7;

  // ============================================================
  // NUEVO: GESTIÓN DE ARCHIVO GARANTIZADA
  // ============================================================
  String? _currentFilePath; // Ruta REAL del archivo guardado
  String? _lastSavedContent; // Contenido del último archivo guardado
  static const String _autoSaveFileName = 'stembosque_current_program.txt';

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
    _initBluetooth();
    _loadAutoSavedFile(); // NUEVO: Cargar archivo auto-guardado si existe
  }

  @override
  void dispose() {
    _codeController.dispose();
    _bleSubscription?.cancel();
    _bleScanSubscription?.cancel();
    _classicSubscription?.cancel();
    _reconnectTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _cleanupConnection();
    super.dispose();
  }

  // ============================================================
  // NUEVO: MÉTODOS DE GESTIÓN DE ARCHIVO GARANTIZADA
  // ============================================================

  /// Obtiene el directorio donde se guardarán los archivos
  Future<Directory> _getAppDirectory() async {
    // Usa el directorio de documentos de la app
    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory('${directory.path}/StemBosque');

    // Crear directorio si no existe
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
      _addLog('📁 Directorio creado: ${appDir.path}', LogType.info);
    }

    return appDir;
  }

  /// Guarda el código actual en un archivo físico
  Future<bool> _saveCodeToFile({String? customFileName}) async {
    try {
      final directory = await _getAppDirectory();
      final fileName = customFileName ?? _autoSaveFileName;
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      final content = _codeController.text;

      // Escribir el archivo
      await file.writeAsString(content);

      // Verificar que se escribió correctamente
      if (await file.exists()) {
        final fileSize = await file.length();
        final readContent = await file.readAsString();

        if (readContent == content) {
          _currentFilePath = filePath;
          _lastSavedContent = content;

          _addLog('✓ Archivo guardado: $fileName', LogType.success);
          _addLog('  Ruta: $filePath', LogType.info);
          _addLog('  Tamaño: $fileSize bytes', LogType.info);

          return true;
        } else {
          throw Exception('Verificación falló: contenido no coincide');
        }
      } else {
        throw Exception('Archivo no se creó correctamente');
      }
    } catch (e) {
      _addLog('✗ Error al guardar archivo: $e', LogType.error);
      return false;
    }
  }

  /// Lee el contenido desde el archivo guardado
  Future<String?> _readCodeFromFile() async {
    if (_currentFilePath == null) {
      _addLog('✗ No hay archivo guardado', LogType.error);
      return null;
    }

    try {
      final file = File(_currentFilePath!);

      if (!await file.exists()) {
        _addLog('✗ Archivo no existe: $_currentFilePath', LogType.error);
        _currentFilePath = null;
        return null;
      }

      final content = await file.readAsString();
      final fileSize = await file.length();

      _addLog('✓ Archivo leído: ${_currentFilePath!.split('/').last}', LogType.success);
      _addLog('  Tamaño: $fileSize bytes', LogType.info);

      return content;
    } catch (e) {
      _addLog('✗ Error al leer archivo: $e', LogType.error);
      return null;
    }
  }

  /// Carga el archivo auto-guardado al iniciar
  Future<void> _loadAutoSavedFile() async {
    try {
      final directory = await _getAppDirectory();
      final filePath = '${directory.path}/$_autoSaveFileName';
      final file = File(filePath);

      if (await file.exists()) {
        final content = await file.readAsString();
        _codeController.text = content;
        _currentFilePath = filePath;
        _lastSavedContent = content;

        _addLog('✓ Archivo previo cargado', LogType.info);
      }
    } catch (e) {
      _addLog('No se pudo cargar archivo previo', LogType.info);
    }
  }

  /// Verifica si el código actual ha cambiado desde la última vez que se guardó
  bool _hasUnsavedChanges() {
    if (_lastSavedContent == null) return true;
    return _codeController.text != _lastSavedContent;
  }

  // ============================================================
  // FIN MÉTODOS DE GESTIÓN DE ARCHIVO
  // ============================================================

  /// Limpieza adecuada de conexiones
  Future<void> _cleanupConnection() async {
    try {
      _connectionTimeoutTimer?.cancel();

      if (_classicConnection != null) {
        if (_classicConnection!.isConnected) {
          await _classicConnection!.close();
        }
        _classicConnection?.dispose();
        _classicConnection = null;
      }

      if (_connectedDevice?.bleDevice != null) {
        await _connectedDevice!.bleDevice!.disconnect();
      }
    } catch (e) {
      debugPrint('Error en limpieza: $e');
    }
  }

  /// Inicializar Bluetooth (BLE y Clásico)
  Future<void> _initBluetooth() async {
    await _requestBluetoothPermissions();

    // Inicializar BLE
    _bleSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _bleState = state;
          _bluetoothEnabled = state == BluetoothAdapterState.on;
        });
      }
    });
    _bleState = await FlutterBluePlus.adapterState.first;

    // Inicializar Bluetooth Clásico
    _classicSubscription = classic.FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      if (mounted) {
        setState(() {
          _bluetoothEnabled = state == classic.BluetoothState.STATE_ON;
        });
      }
    });

    // Verificar estado inicial de Bluetooth Clásico
    classic.BluetoothState classicState = await classic.FlutterBluetoothSerial.instance.state;
    setState(() {
      _bluetoothEnabled = classicState == classic.BluetoothState.STATE_ON ||
          _bleState == BluetoothAdapterState.on;
    });
  }

  /// Solicitar permisos de Bluetooth
  Future<void> _requestBluetoothPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.storage, // NUEVO: Para guardar archivos
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('StemBosque IDE'),
            if (_hasUnsavedChanges()) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Sin guardar',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _executeProgram,
              icon: _isRunning
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.play_arrow, size: 20),
              label: Text(_isRunning ? 'Ejecutando...' : 'Ejecutar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRunning ? AppTheme.comment : AppTheme.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawerMenu(),
      body: Column(
        children: [
          if (_showBluetoothPanel) _buildBluetoothPanel(),
          Expanded(
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
        ],
      ),
    );
  }

  Widget _buildDrawerMenu() {
    return Drawer(
      backgroundColor: AppTheme.background,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: BoxDecoration(
              color: AppTheme.currentLine,
              border: Border(
                bottom: BorderSide(color: AppTheme.comment, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.code, size: 40, color: AppTheme.cyan),
                const SizedBox(height: 12),
                const Text(
                  'StemBosque IDE',
                  style: TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Opciones del editor',
                  style: TextStyle(color: AppTheme.comment, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.folder_open,
                  title: 'Abrir archivo',
                  subtitle: 'Cargar código desde archivo',
                  color: AppTheme.cyan,
                  onTap: () {
                    Navigator.pop(context);
                    _openFile();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.save,
                  title: 'Guardar archivo',
                  subtitle: _hasUnsavedChanges() ? 'Hay cambios sin guardar' : 'Código guardado',
                  color: _hasUnsavedChanges() ? AppTheme.orange : AppTheme.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _saveFile();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.share,
                  title: 'Compartir archivo',
                  subtitle: 'Enviar por Bluetooth u otra app',
                  color: AppTheme.cyan,
                  onTap: () {
                    Navigator.pop(context);
                    _shareFileViaBluetooth();
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.clear_all,
                  title: 'Limpiar código',
                  subtitle: 'Borrar todo el editor',
                  color: AppTheme.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _clearCode();
                  },
                ),
                const Divider(color: AppTheme.currentLine, height: 1),
                _buildDrawerItem(
                  icon: _bluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                  title: 'Bluetooth',
                  subtitle: _bluetoothEnabled ? 'Disponible' : 'Desactivado',
                  color: _bluetoothEnabled ? AppTheme.green : AppTheme.red,
                  trailing: Switch(
                    value: _showBluetoothPanel,
                    onChanged: (value) {
                      Navigator.pop(context);
                      _toggleBluetoothPanel();
                    },
                    activeColor: AppTheme.green,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleBluetoothPanel();
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.currentLine, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isRunning ? Icons.pending : Icons.check_circle,
                      size: 16,
                      color: _isRunning ? AppTheme.orange : AppTheme.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isRunning ? 'Ejecutando...' : 'Listo',
                      style: TextStyle(color: AppTheme.comment, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_currentFilePath != null) ...[
                  Text(
                    '📁 ${_currentFilePath!.split('/').last}',
                    style: TextStyle(color: AppTheme.cyan, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'Versión 1.0.4 (File Guaranteed)',
                  style: TextStyle(color: AppTheme.comment, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: AppTheme.comment, fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildHorizontalDivider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            final height = MediaQuery.of(context).size.height;
            _horizontalSplitRatio = (_horizontalSplitRatio + details.delta.dy / height).clamp(0.3, 0.9);
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

  // ============================================================
  // MÉTODO PRINCIPAL DE EJECUCIÓN - COMPLETAMENTE REDISEÑADO
  // ============================================================

  Future<void> _executeProgram() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _consoleMessages.clear();
    });

    try {
      // PASO 1: Verificar conexión Bluetooth
      if (_connectedDevice == null) {
        _addLog('✗ No hay dispositivo Bluetooth conectado', LogType.error);
        setState(() => _isRunning = false);

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.currentLine,
              title: Row(
                children: [
                  Icon(Icons.bluetooth_disabled, color: AppTheme.red),
                  const SizedBox(width: 12),
                  const Text('Sin conexión Bluetooth', style: TextStyle(color: AppTheme.foreground)),
                ],
              ),
              content: const Text(
                'Necesitas conectar un dispositivo Bluetooth antes de ejecutar el programa.',
                style: TextStyle(color: AppTheme.foreground),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido', style: TextStyle(color: AppTheme.cyan)),
                ),
              ],
            ),
          );
        }
        return;
      }

      _addLog('✓ Dispositivo conectado: ${_connectedDevice!.displayName}', LogType.success);

      // PASO 2: Verificar que hay código
      if (_codeController.text.trim().isEmpty) {
        _addLog('✗ El código está vacío', LogType.error);
        setState(() => _isRunning = false);
        return;
      }

      // PASO 3: Compilar el código
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.info);
      _addLog('FASE 1: COMPILACIÓN', LogType.info);
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.info);

      final lexer = Lexer(_codeController.text);
      final tokens = lexer.tokenize();
      _addLog('✓ Análisis léxico: ${tokens.length} tokens', LogType.success);

      final parser = Parser(tokens);
      final ast = parser.parse();
      _addLog('✓ Análisis sintáctico completado', LogType.success);

      final analyzer = SemanticAnalyzer();
      final isValid = analyzer.analyze(ast);

      if (!isValid) {
        _addLog('✗ Errores semánticos detectados:', LogType.error);
        for (final error in analyzer.errors) {
          _addLog('  $error', LogType.error);
        }
        setState(() => _isRunning = false);
        return;
      }
      _addLog('✓ Análisis semántico completado', LogType.success);

      final executor = ProgramExecutor();
      final instructions = executor.execute(ast);
      _addLog('✓ Compilación exitosa: ${instructions.length} instrucciones', LogType.success);

      // PASO 4: GUARDAR ARCHIVO (OBLIGATORIO)
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.info);
      _addLog('FASE 2: GUARDAR ARCHIVO', LogType.info);
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.info);

      // Verificar si hay cambios sin guardar
      if (_hasUnsavedChanges()) {
        _addLog('⚠ Hay cambios sin guardar', LogType.info);

        // Guardar automáticamente
        _addLog('💾 Guardando archivo...', LogType.info);
        bool saved = await _saveCodeToFile();

        if (!saved) {
          _addLog('✗ Error al guardar archivo', LogType.error);
          setState(() => _isRunning = false);

          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppTheme.currentLine,
                title: Row(
                  children: [
                    Icon(Icons.error, color: AppTheme.red),
                    const SizedBox(width: 12),
                    const Text('Error al guardar', style: TextStyle(color: AppTheme.foreground)),
                  ],
                ),
                content: const Text(
                  'No se pudo guardar el archivo. Verifica los permisos de almacenamiento.',
                  style: TextStyle(color: AppTheme.foreground),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendido', style: TextStyle(color: AppTheme.cyan)),
                  ),
                ],
              ),
            );
          }
          return;
        }
      } else {
        _addLog('✓ Archivo ya está guardado', LogType.success);
      }

      // PASO 5: VERIFICAR QUE EL ARCHIVO EXISTE
      _addLog('🔍 Verificando archivo guardado...', LogType.info);

      if (_currentFilePath == null) {
        throw Exception('No hay ruta de archivo definida');
      }

      final file = File(_currentFilePath!);
      if (!await file.exists()) {
        throw Exception('Archivo no existe en: $_currentFilePath');
      }

      final fileSize = await file.length();
      _addLog('✓ Archivo verificado: ${fileSize} bytes', LogType.success);

      // PASO 6: ENVIAR ARCHIVO POR BLUETOOTH
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.info);
      _addLog('FASE 3: ENVÍO BLUETOOTH', LogType.info);
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.info);

      await _sendFileToDeviceGuaranteed();

    } catch (e) {
      _addLog('✗ Error crítico: $e', LogType.error);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.currentLine,
            title: Row(
              children: [
                Icon(Icons.error, color: AppTheme.red),
                const SizedBox(width: 12),
                const Text('Error', style: TextStyle(color: AppTheme.foreground)),
              ],
            ),
            content: Text(
              'Error: $e',
              style: const TextStyle(color: AppTheme.foreground),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar', style: TextStyle(color: AppTheme.cyan)),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isRunning = false);
    }
  }

  // ============================================================
  // MÉTODO DE ENVÍO GARANTIZADO
  // ============================================================

  Future<void> _sendFileToDeviceGuaranteed() async {
    if (_connectedDevice == null) {
      throw Exception('No hay dispositivo conectado');
    }

    if (_currentFilePath == null) {
      throw Exception('No hay archivo guardado');
    }

    try {
      // LEER DESDE EL ARCHIVO FÍSICO (NO desde _codeController)
      _addLog('📖 Leyendo desde archivo...', LogType.info);
      final fileContent = await _readCodeFromFile();

      if (fileContent == null) {
        throw Exception('No se pudo leer el archivo');
      }

      _addLog('✓ Contenido leído: ${fileContent.length} caracteres', LogType.success);

      // Verificar que el dispositivo sigue conectado
      if (_connectedDevice!.type == BluetoothDeviceType.classic) {
        if (_classicConnection == null || !_classicConnection!.isConnected) {
          throw Exception('Conexión Bluetooth perdida');
        }
      }

      _addLog('📤 Enviando archivo por Bluetooth...', LogType.info);
      _addLog('  Dispositivo: ${_connectedDevice!.displayName}', LogType.info);
      _addLog('  Tipo: ${_connectedDevice!.type == BluetoothDeviceType.ble ? "BLE" : "Clásico"}', LogType.info);

      // Enviar según el tipo de dispositivo
      if (_connectedDevice!.type == BluetoothDeviceType.ble) {
        await _sendViaBLEGuaranteed(fileContent);
      } else {
        await _sendViaClassicGuaranteed(fileContent);
      }

    } catch (e) {
      _addLog('✗ Error en envío: $e', LogType.error);
      rethrow;
    }
  }

  Future<void> _sendViaBLEGuaranteed(String content) async {
    _addLog('🔍 Descubriendo servicios BLE...', LogType.info);

    List<BluetoothService> services = await _connectedDevice!.bleDevice!.discoverServices();

    BluetoothCharacteristic? writeCharacteristic;
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          writeCharacteristic = characteristic;
          break;
        }
      }
      if (writeCharacteristic != null) break;
    }

    if (writeCharacteristic == null) {
      throw Exception('No se encontró característica de escritura BLE');
    }

    _addLog('✓ Característica de escritura encontrada', LogType.success);

    List<int> bytes = utf8.encode(content);
    int totalChunks = (bytes.length / 20).ceil();

    _addLog('📊 Total a enviar: ${bytes.length} bytes en $totalChunks paquetes', LogType.info);

    for (int i = 0; i < bytes.length; i += 20) {
      int end = (i + 20 < bytes.length) ? i + 20 : bytes.length;
      await writeCharacteristic.write(bytes.sublist(i, end), withoutResponse: false);

      int chunkNumber = (i ~/ 20) + 1;
      if (chunkNumber % 10 == 0) {
        _addLog('  Progreso: $chunkNumber/$totalChunks paquetes', LogType.info);
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }

    _addLog('✓ Envío BLE completado', LogType.success);
    _showSuccessDialog(bytes.length, totalChunks);
  }

  Future<void> _sendViaClassicGuaranteed(String content) async {
    if (_classicConnection == null || !_classicConnection!.isConnected) {
      throw Exception('Conexión Bluetooth Clásica perdida');
    }

    List<int> bytes = utf8.encode(content);
    _addLog('📊 Total a enviar: ${bytes.length} bytes', LogType.info);

    try {
      // Enviar los bytes
      _classicConnection!.output.add(Uint8List.fromList(bytes));

      _addLog('⏳ Esperando confirmación de envío...', LogType.info);

      // Esperar a que se envíen todos los datos
      await _classicConnection!.output.allSent;

      // Verificar que la conexión sigue activa
      if (!_classicConnection!.isConnected) {
        throw Exception('Conexión se perdió durante la transmisión');
      }

      _addLog('✓ Envío Bluetooth Clásico completado', LogType.success);
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.success);
      _addLog('✅ TRANSMISIÓN EXITOSA', LogType.success);
      _addLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', LogType.success);

      _showSuccessDialog(bytes.length, 1);

    } catch (e) {
      await _cleanupConnection();
      if (mounted) {
        setState(() => _connectedDevice = null);
      }
      rethrow;
    }
  }

  void _clearCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        title: const Text('Limpiar código', style: TextStyle(color: AppTheme.foreground)),
        content: const Text(
          '¿Está seguro de que desea limpiar todo el código?',
          style: TextStyle(color: AppTheme.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.comment)),
          ),
          TextButton(
            onPressed: () {
              _codeController.clear();
              _currentFilePath = null;
              _lastSavedContent = null;
              Navigator.pop(context);
              _addLog('Código limpiado', LogType.info);
            },
            child: const Text('Limpiar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile() async {
    try {
      final content = await _openFileFromStemBosqueDirectory();

      if (content != null) {
        _codeController.text = content;
        _currentFilePath = null;
        _lastSavedContent = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.green),
                  const SizedBox(width: 12),
                  const Text('Archivo cargado exitosamente'),
                ],
              ),
              backgroundColor: AppTheme.currentLine,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _addLog('Error al abrir archivo: $e', LogType.error);
    }
  }


  Future<void> _saveFile() async {
    try {
      final saved = await _saveCodeToFile();
      if (saved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.green),
                  const SizedBox(width: 12),
                  const Text('Archivo guardado exitosamente'),
                ],
              ),
              backgroundColor: AppTheme.currentLine,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _addLog('Error al guardar archivo: $e', LogType.error);
    }
  }

  Future<void> _shareFileViaBluetooth() async {
    // Primero guardar si hay cambios
    if (_hasUnsavedChanges()) {
      await _saveCodeToFile();
    }

    if (_currentFilePath == null) {
      _addLog('✗ No hay archivo guardado para compartir', LogType.error);
      return;
    }

    final file = File(_currentFilePath!);
    if (!await file.exists()) {
      _addLog('✗ Archivo no encontrado', LogType.error);
      return;
    }

    // Abre el menú nativo de Android para compartir
    await Share.shareXFiles(
      [XFile(_currentFilePath!)],
      subject: 'Programa StemBosque',
    );

    _addLog('✓ Menú de compartir abierto', LogType.success);
  }

  void _clearConsole() {
    setState(() {
      _consoleMessages.clear();
      _addLog('Consola limpiada', LogType.info);
    });
  }

  // === MÉTODOS BLUETOOTH (mantienen la implementación anterior) ===

  void _toggleBluetoothPanel() {
    setState(() => _showBluetoothPanel = !_showBluetoothPanel);
    if (_showBluetoothPanel && _bluetoothEnabled) {
      _startUnifiedScan();
    }
  }

  Future<void> _toggleBluetooth() async {
    if (_bluetoothEnabled) {
      await FlutterBluePlus.turnOff();
      await classic.FlutterBluetoothSerial.instance.requestDisable();
      _addLog('Bluetooth desactivado', LogType.info);
    } else {
      await FlutterBluePlus.turnOn();
      await classic.FlutterBluetoothSerial.instance.requestEnable();
      _addLog('Bluetooth activado', LogType.success);
    }
  }

  Future<void> _startUnifiedScan() async {
    if (_isScanning || !_bluetoothEnabled) return;

    setState(() {
      _discoveredDevices.clear();
      _isScanning = true;
    });

    _addLog('🔍 Escaneando dispositivos Bluetooth...', LogType.info);

    try {
      List<classic.BluetoothDevice> classicDevices =
      await classic.FlutterBluetoothSerial.instance.getBondedDevices();

      for (var device in classicDevices) {
        setState(() {
          _discoveredDevices.add(UnifiedBluetoothDevice(
            name: device.name ?? '',
            address: device.address,
            type: BluetoothDeviceType.classic,
            classicDevice: device,
          ));
        });
      }

      _addLog('✓ ${classicDevices.length} dispositivos Clásicos vinculados', LogType.success);

      _addLog('⏳ Buscando dispositivos Clásicos cercanos...', LogType.info);

      StreamSubscription<classic.BluetoothDiscoveryResult>? classicDiscoverySubscription;

      classicDiscoverySubscription = classic.FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
        bool exists = _discoveredDevices.any((d) => d.address == result.device.address);

        if (!exists && mounted) {
          setState(() {
            _discoveredDevices.add(UnifiedBluetoothDevice(
              name: result.device.name ?? '',
              address: result.device.address,
              type: BluetoothDeviceType.classic,
              rssi: result.rssi,
              classicDevice: result.device,
            ));
          });
          _addLog('  → Encontrado: ${result.device.name ?? result.device.address}', LogType.info);
        }
      });

      await Future.delayed(const Duration(seconds: 12));
      await classicDiscoverySubscription.cancel();

      _bleScanSubscription?.cancel();
      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          for (var result in results) {
            bool exists = _discoveredDevices.any((d) =>
            d.type == BluetoothDeviceType.ble &&
                d.bleDevice?.remoteId == result.device.remoteId
            );

            if (!exists) {
              setState(() {
                _discoveredDevices.add(UnifiedBluetoothDevice(
                  name: result.device.platformName,
                  address: result.device.remoteId.toString(),
                  type: BluetoothDeviceType.ble,
                  rssi: result.rssi,
                  bleDevice: result.device,
                ));
              });
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();

      _addLog('✓ Escaneo completado: ${_discoveredDevices.length} dispositivos', LogType.success);
    } catch (e) {
      _addLog('✗ Error al escanear: $e', LogType.error);
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
    _addLog('Escaneo detenido', LogType.info);
  }

  Future<void> _openBluetoothSettings() async {
    try {
      await classic.FlutterBluetoothSerial.instance.openSettings();
      _addLog('→ Abriendo configuración de Bluetooth...', LogType.info);
    } catch (e) {
      _addLog('✗ Error al abrir configuración: $e', LogType.error);
    }
  }

  Future<void> _connectToDevice(UnifiedBluetoothDevice device) async {
    if (_isConnecting) {
      _addLog('⚠ Ya hay una conexión en proceso...', LogType.info);
      return;
    }

    setState(() => _isConnecting = true);
    _reconnectAttempts = 0;

    try {
      await _connectToDeviceInternal(device);
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }
  /// Detecta si un dispositivo es de audio (audífonos, parlantes, etc.)
  bool _isAudioDevice(UnifiedBluetoothDevice device) {
    String name = device.name.toLowerCase();

    // Palabras clave de dispositivos de audio
    List<String> audioKeywords = [
      'airpods', 'buds', 'earbuds', 'headphone', 'headset',
      'speaker', 'soundbar', 'jbl', 'bose', 'sony',
      'beats', 'audio', 'sound', 'music', 'galaxy buds',
      'xiaomi buds', 'redmi buds', 'freebuds', 'audifonos'
    ];

    return audioKeywords.any((keyword) => name.contains(keyword));
  }

  /// Muestra advertencia para dispositivos de audio
  Future<bool?> _showAudioDeviceWarning(UnifiedBluetoothDevice device) async {
    if (!mounted) return false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        title: Row(
          children: [
            Icon(Icons.headset_off, color: AppTheme.orange),
            const SizedBox(width: 12),
            const Text('Dispositivo de audio detectado',
                style: TextStyle(color: AppTheme.foreground)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Has seleccionado: ${device.displayName}',
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.orange),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '⚠️ Este parece ser un dispositivo de audio',
                      style: TextStyle(
                        color: AppTheme.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Los audífonos y parlantes NO pueden recibir archivos de '
                          'programas. Solo sirven para reproducir audio.\n\n'
                          'Intentar conectar puede causar que la app se congele o crashee.',
                      style: TextStyle(color: AppTheme.foreground, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '✓ DISPOSITIVOS COMPATIBLES:',
                style: TextStyle(
                  color: AppTheme.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...[
                '• Arduino con módulo Bluetooth',
                '• ESP32 con Bluetooth Classic',
                '• PC con servidor SPP activo',
                '• Otro celular con app servidor',
              ].map((text) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  text,
                  style: const TextStyle(color: AppTheme.foreground, fontSize: 11),
                ),
              )).toList(),
              const SizedBox(height: 16),
              const Text(
                'NO intentes conectar a menos que estés 100% seguro.',
                style: TextStyle(
                  color: AppTheme.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              foregroundColor: AppTheme.background,
            ),
            child: const Text('Cancelar (Recomendado)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Conectar de todos modos',
              style: TextStyle(color: AppTheme.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDeviceInternal(UnifiedBluetoothDevice device) async {
    // NUEVO: Protección contra dispositivos de audio
    if (_isAudioDevice(device)) {
      _addLog('⚠️ Dispositivo de audio detectado', LogType.info);

      bool? shouldContinue = await _showAudioDeviceWarning(device);

      if (shouldContinue != true) {
        _addLog('❌ Conexión cancelada por el usuario', LogType.info);
        return;
      }

      _addLog('⚠️ Procediendo bajo riesgo del usuario...', LogType.info);
    }

    // NUEVO: Envolver TODO en try-catch para evitar crashes
    try {
      _addLog('🔌 Conectando a ${device.displayName}...', LogType.info);

      if (device.type == BluetoothDeviceType.ble) {
        try {
          await device.bleDevice!.connect(timeout: const Duration(seconds: 15));

          if (mounted) {
            setState(() => _connectedDevice = device);
          }

          _addLog('✓ Conectado (BLE)', LogType.success);
          _addLog('ℹ️ Dispositivo: ${device.displayName}', LogType.info);

          // NUEVO: Advertencia si es dispositivo de audio
          if (_isAudioDevice(device)) {
            _addLog('⚠️ Este dispositivo puede NO soportar transferencia de archivos', LogType.info);
          }

          return;
        } catch (e) {
          _addLog('✗ Error en conexión BLE: $e', LogType.error);

          if (mounted) {
            _showSafeErrorDialog(
              'Error de conexión BLE',
              'No se pudo conectar al dispositivo.\n\n'
                  'Posibles causas:\n'
                  '• El dispositivo está fuera de rango\n'
                  '• El dispositivo no acepta conexiones\n'
                  '• Es un dispositivo de solo audio',
            );
          }

          return;
        }
      }

      // Bluetooth Clásico con protección completa
      try {
        _addLog('  📋 Paso 1: Limpiando conexiones previas...', LogType.info);
        await _cleanupConnection();
        await Future.delayed(const Duration(milliseconds: 1500));

        _addLog('  📋 Paso 2: Verificando emparejamiento...', LogType.info);
        List<classic.BluetoothDevice> bondedDevices =
        await classic.FlutterBluetoothSerial.instance.getBondedDevices();

        classic.BluetoothDevice? targetDevice = bondedDevices
            .cast<classic.BluetoothDevice?>()
            .firstWhere(
              (d) => d?.address == device.address,
          orElse: () => null,
        );

        if (targetDevice == null) {
          _addLog('  ⚠ Dispositivo no emparejado. Iniciando emparejamiento...', LogType.info);

          bool? paired = await classic.FlutterBluetoothSerial.instance
              .bondDeviceAtAddress(device.address)
              .timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );

          if (paired != true) {
            throw Exception('Emparejamiento cancelado o rechazado');
          }

          _addLog('  ✓ Emparejamiento exitoso', LogType.success);
          await Future.delayed(const Duration(seconds: 5));

          bondedDevices = await classic.FlutterBluetoothSerial.instance.getBondedDevices();
          targetDevice = bondedDevices
              .cast<classic.BluetoothDevice?>()
              .firstWhere(
                (d) => d?.address == device.address,
            orElse: () => null,
          );

          if (targetDevice == null) {
            throw Exception('No se pudo obtener dispositivo después del emparejamiento');
          }
        } else {
          _addLog('  ✓ Dispositivo ya emparejado', LogType.info);
        }

        _addLog('  📋 Paso 3: Estableciendo conexión SPP...', LogType.info);

        classic.BluetoothConnection? connection;
        bool connectionSuccessful = false;

        try {
          _connectionTimeoutTimer = Timer(const Duration(seconds: 30), () {
            if (!connectionSuccessful) {
              _addLog('  ⏱ Timeout alcanzado (30s)', LogType.error);
            }
          });

          // NUEVO: Timeout más corto y manejo más robusto
          connection = await classic.BluetoothConnection.toAddress(device.address)
              .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Timeout de conexión'),
          );

          _connectionTimeoutTimer?.cancel();
          connectionSuccessful = true;

          if (connection == null) {
            throw Exception('Conexión retornó null');
          }

          await Future.delayed(const Duration(milliseconds: 500));

          if (!connection.isConnected) {
            connection.dispose();
            throw Exception('Conexión establecida pero no está activa');
          }

          _addLog('  ✓ Conexión SPP establecida', LogType.success);

        } on TimeoutException catch (e) {
          _connectionTimeoutTimer?.cancel();
          throw Exception('Timeout: El dispositivo no respondió en 30 segundos');
        } catch (e) {
          _connectionTimeoutTimer?.cancel();

          String errorMsg = e.toString().toLowerCase();

          if (errorMsg.contains('read failed') ||
              errorMsg.contains('socket might closed') ||
              errorMsg.contains('socket closed')) {
            throw Exception(
                'El dispositivo rechazó la conexión.\n\n'
                    'Posibles causas:\n'
                    '• Es un dispositivo de solo audio (audífonos/parlantes)\n'
                    '• No tiene servidor SPP activo\n'
                    '• Está ocupado con otra conexión'
            );
          }

          rethrow;
        }

        _classicConnection = connection;

        if (mounted) {
          setState(() {
            _connectedDevice = UnifiedBluetoothDevice(
              name: targetDevice!.name ?? device.name,
              address: targetDevice.address,
              type: BluetoothDeviceType.classic,
              classicDevice: targetDevice,
            );
          });
        }

        _addLog('✓ Conectado exitosamente a ${device.displayName}', LogType.success);
        _addLog('ℹ️ Tipo: Bluetooth Clásico (SPP)', LogType.info);

        // NUEVO: Advertencia si es dispositivo de audio
        if (_isAudioDevice(device)) {
          _addLog('⚠️ Este dispositivo puede NO soportar transferencia de archivos', LogType.info);
        }

        _reconnectAttempts = 0;
        _monitorConnection();

      } catch (e) {
        String errorMsg = e.toString();
        _addLog('✗ Error de conexión: $errorMsg', LogType.error);

        await _cleanupConnection();

        if (mounted) {
          bool isAudioDevice = _isAudioDevice(device);

          _showSafeErrorDialog(
            'No se pudo conectar',
            errorMsg,
            isAudioDevice: isAudioDevice,
          );
        }

        // Decidir si reintentar
        if (mounted &&
            _reconnectAttempts < _maxReconnectAttempts &&
            !errorMsg.toLowerCase().contains('cancelado') &&
            !errorMsg.toLowerCase().contains('rechazó') &&
            !_isAudioDevice(device)) { // No reintentar en dispositivos de audio

          bool? retry = await _showRetryDialog(device, errorMsg);

          if (retry == true) {
            _reconnectAttempts++;
            _addLog('🔄 Reintentando... (${_reconnectAttempts}/$_maxReconnectAttempts)', LogType.info);
            await Future.delayed(Duration(seconds: 3 * _reconnectAttempts));
            await _connectToDeviceInternal(device);
          }
        }
      }

    } catch (e) {
      // Catch-all para cualquier error no manejado
      _addLog('✗ Error inesperado: $e', LogType.error);

      if (mounted) {
        _showSafeErrorDialog(
          'Error inesperado',
          'Ocurrió un error al intentar conectar.\n\n'
              'Error: ${e.toString()}',
        );
      }
    }
  }

  /// NUEVO: Diálogo de error seguro que no crashea
  void _showSafeErrorDialog(String title, String message, {bool isAudioDevice = false}) {
    if (!mounted) return;

    try {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.currentLine,
          title: Row(
            children: [
              Icon(
                isAudioDevice ? Icons.headset_off : Icons.error,
                color: isAudioDevice ? AppTheme.orange : AppTheme.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppTheme.foreground),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: AppTheme.foreground, fontSize: 13),
                ),
                if (isAudioDevice) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '💡 Tip: Los dispositivos de audio (audífonos, parlantes) '
                          'no están diseñados para recibir archivos. '
                          'Usa un Arduino, ESP32 o PC con servidor SPP.',
                      style: TextStyle(color: AppTheme.cyan, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.green,
                foregroundColor: AppTheme.background,
              ),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error mostrando diálogo: $e');
    }
  }

  Future<bool?> _showRetryDialog(UnifiedBluetoothDevice device, String error) async {
    if (!mounted) return false;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        title: Row(
          children: [
            Icon(Icons.warning, color: AppTheme.orange),
            const SizedBox(width: 12),
            const Text('Error de conexión', style: TextStyle(color: AppTheme.foreground)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No se pudo conectar con ${device.displayName}',
                style: const TextStyle(
                  color: AppTheme.foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  error.length > 150 ? '${error.substring(0, 150)}...' : error,
                  style: const TextStyle(
                    color: AppTheme.comment,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Intento ${_reconnectAttempts + 1} de $_maxReconnectAttempts',
                style: const TextStyle(color: AppTheme.cyan, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.comment)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              foregroundColor: AppTheme.background,
            ),
          ),
        ],
      ),
    );
  }

  void _monitorConnection() {
    _reconnectTimer?.cancel();

    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_classicConnection != null && !_classicConnection!.isConnected) {
        _addLog('⚠ Conexión perdida', LogType.error);
        timer.cancel();
        if (mounted) {
          setState(() => _connectedDevice = null);
        }
        _cleanupConnection();
      }
    });
  }

  Future<void> _disconnectDevice() async {
    if (_connectedDevice != null) {
      try {
        _reconnectTimer?.cancel();
        _connectionTimeoutTimer?.cancel();

        if (_connectedDevice!.type == BluetoothDeviceType.ble) {
          await _connectedDevice!.bleDevice!.disconnect();
        } else {
          await _cleanupConnection();
        }

        if (mounted) {
          setState(() => _connectedDevice = null);
        }
        _addLog('Desconectado', LogType.info);
      } catch (e) {
        _addLog('Error al desconectar: $e', LogType.error);
      }
    }
  }

  void _showSuccessDialog(int bytes, int chunks) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.currentLine,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.green, size: 28),
              const SizedBox(width: 12),
              const Text('Envío exitoso', style: TextStyle(color: AppTheme.foreground)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '✅ Archivo enviado correctamente',
                style: TextStyle(
                  color: AppTheme.foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('📊 Tamaño', '$bytes bytes'),
              _buildInfoRow('📁 Archivo', _currentFilePath!.split('/').last),
              _buildInfoRow('📡 Dispositivo', _connectedDevice!.displayName),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.green,
                foregroundColor: AppTheme.background,
              ),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.cyan,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.foreground,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothPanel() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.currentLine, width: 2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.currentLine,
              border: Border(bottom: BorderSide(color: AppTheme.comment, width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _bluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                      color: _bluetoothEnabled ? AppTheme.cyan : AppTheme.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _bluetoothEnabled ? 'Bluetooth' : 'Bluetooth Desactivado',
                      style: TextStyle(
                        color: _bluetoothEnabled ? AppTheme.cyan : AppTheme.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _toggleBluetooth,
                      icon: Icon(
                        _bluetoothEnabled ? Icons.bluetooth_disabled : Icons.bluetooth,
                        size: 18,
                      ),
                      label: Text(_bluetoothEnabled ? 'Apagar' : 'Encender'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _bluetoothEnabled ? AppTheme.red : AppTheme.green,
                        foregroundColor: AppTheme.background,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_bluetoothEnabled)
                      ElevatedButton.icon(
                        onPressed: _isScanning ? _stopScan : _startUnifiedScan,
                        icon: Icon(_isScanning ? Icons.stop : Icons.search, size: 18),
                        label: Text(_isScanning ? 'Detener' : 'Escanear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning ? AppTheme.orange : AppTheme.purple,
                          foregroundColor: AppTheme.background,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _toggleBluetoothPanel,
                      icon: const Icon(Icons.close),
                      color: AppTheme.comment,
                    ),
                  ],
                ),
                if (_bluetoothEnabled && _discoveredDevices.isEmpty && !_isScanning)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.orange, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.orange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¿No ves tu dispositivo? Vincúlalo primero desde la configuración',
                            style: TextStyle(color: AppTheme.foreground, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _openBluetoothSettings,
                          icon: const Icon(Icons.settings_bluetooth, size: 16),
                          label: const Text('Vincular'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cyan,
                            foregroundColor: AppTheme.background,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_connectedDevice != null)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.currentLine,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.green, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_connected, color: AppTheme.green, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONECTADO',
                          style: const TextStyle(
                            color: AppTheme.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _connectedDevice!.displayName,
                          style: const TextStyle(
                            color: AppTheme.foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _disconnectDevice,
                    icon: const Icon(Icons.close),
                    color: AppTheme.red,
                  ),
                ],
              ),
            ),
          Expanded(child: _buildDeviceList()),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (!_bluetoothEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 48, color: AppTheme.comment),
            const SizedBox(height: 12),
            Text('Active el Bluetooth', style: TextStyle(color: AppTheme.comment)),
          ],
        ),
      );
    }

    if (_isScanning && _discoveredDevices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.cyan),
            SizedBox(height: 12),
            Text('Buscando...', style: TextStyle(color: AppTheme.foreground)),
          ],
        ),
      );
    }

    if (_discoveredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.devices, size: 48, color: AppTheme.comment),
            const SizedBox(height: 12),
            Text('No se encontraron dispositivos', style: TextStyle(color: AppTheme.comment)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _discoveredDevices.length,
      itemBuilder: (context, index) {
        final device = _discoveredDevices[index];
        final isConnected = _connectedDevice?.address == device.address;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.currentLine,
            borderRadius: BorderRadius.circular(6),
            border: isConnected ? Border.all(color: AppTheme.green, width: 2) : null,
          ),
          child: ListTile(
            dense: true,
            leading: Icon(
              device.type == BluetoothDeviceType.ble ? Icons.bluetooth : Icons.bluetooth_connected,
              color: isConnected ? AppTheme.green : AppTheme.cyan,
              size: 24,
            ),
            title: Text(
              device.displayName,
              style: const TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              device.address,
              style: const TextStyle(color: AppTheme.comment, fontSize: 11),
            ),
            trailing: isConnected
                ? const Chip(
              label: Text('Conectado', style: TextStyle(fontSize: 10)),
              backgroundColor: AppTheme.green,
            )
                : ElevatedButton(
              onPressed: _isConnecting ? null : () => _connectToDevice(device),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: AppTheme.foreground,
              ),
              child: Text(_isConnecting ? 'Conectando...' : 'Conectar'),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _openFileFromStemBosqueDirectory() async {
    try {
      final directory = await _getAppDirectory();

      // Listar todos los archivos en el directorio
      List<FileSystemEntity> entities = directory.listSync();
      List<File> files = entities
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt') || file.path.endsWith('.sb'))
          .toList();

      if (files.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.currentLine,
              title: Row(
                children: [
                  Icon(Icons.folder_open, color: AppTheme.orange),
                  const SizedBox(width: 12),
                  const Text('Sin archivos', style: TextStyle(color: AppTheme.foreground)),
                ],
              ),
              content: Text(
                'No hay archivos guardados en la carpeta de StemBosque.\n\n'
                    'Carpeta: ${directory.path}',
                style: const TextStyle(color: AppTheme.foreground),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido', style: TextStyle(color: AppTheme.cyan)),
                ),
              ],
            ),
          );
        }
        return null;
      }

      // Mostrar diálogo con lista de archivos
      File? selectedFile = await showDialog<File>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.currentLine,
          title: Row(
            children: [
              Icon(Icons.folder_open, color: AppTheme.cyan),
              const SizedBox(width: 12),
              const Text('Seleccionar archivo', style: TextStyle(color: AppTheme.foreground)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final fileName = file.path.split('/').last;
                final fileStat = file.statSync();
                final fileSize = fileStat.size;
                final modified = fileStat.modified;

                return Card(
                  color: AppTheme.background,
                  child: ListTile(
                    leading: Icon(Icons.insert_drive_file, color: AppTheme.cyan),
                    title: Text(
                      fileName,
                      style: const TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(fileSize / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(color: AppTheme.comment, fontSize: 11),
                        ),
                        Text(
                          'Modificado: ${_formatDate(modified)}',
                          style: TextStyle(color: AppTheme.comment, fontSize: 10),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.pop(context, file),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.comment)),
            ),
          ],
        ),
      );

      if (selectedFile != null) {
        final content = await selectedFile.readAsString();
        _addLog('✓ Archivo abierto: ${selectedFile.path.split('/').last}', LogType.success);
        return content;
      }

      return null;
    } catch (e) {
      _addLog('✗ Error al abrir archivo: $e', LogType.error);
      return null;
    }
  }

// Helper para formatear fechas
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _addLog(String message, LogType type) {
    if (mounted) {
      setState(() {
        _consoleMessages.add(LogMessage(message: message, type: type));
      });
    }
  }
}