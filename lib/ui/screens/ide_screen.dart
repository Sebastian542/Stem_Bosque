import 'dart:io';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../bluetooth/bluetooth_manager.dart';
import '../../compiler/compiler.dart';
import '../../services/file_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/bluetooth_panel.dart';
import '../widgets/code_editor_validated.dart';
import '../widgets/toolbar.dart';
import '../widgets/ide_drawer.dart';
import '../widgets/confetti_widget.dart';
import 'simulation_screen.dart';
import '../widgets/vampirito_pet.dart';
import 'dart:async';

class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  final _bt = BluetoothManager.instance;
  final _fm = FileManager.instance;

  // ── Editor ───────────────────────────────────────────────────
  final _codeController = CodeEditorController();
  bool         _isRunning       = false;
  bool         _codeIsValid     = false;
  bool         _compiledSuccess = false;
  OverlayEntry? _confettiOverlay;
  OverlayEntry? _vampiritoOverlay;
  bool          _vampiritoAnimating = false;
  List<String> _compiledLines   = [];
  String?      _compiledFilePath;
  String?      _lastErrorMessage;
  bool _isTyping = false;
  Timer? _typingTimer;

  // ── Bluetooth UI ─────────────────────────────────────────────
  bool _bluetoothEnabled   = false;
  bool _showBluetoothPanel = false;
  final List<UnifiedBluetoothDevice> _discoveredDevices = [];

  bool get _isScanning    => _bt.isScanning;
  bool get _isConnecting  => _bt.isConnecting;
  UnifiedBluetoothDevice? get _connectedDevice => _bt.connectedDevice;

  static const String _sampleCode = '''/*Un sencillo programa de ejemplo.*/
PROGRAMA "Programa numero 1"

  AVANZAR 5
  AVANZAR -5
  GIRAR 5
  GIRAR -5

  N=100
  Contador = 1

  REPETIR [N] VECES:
    GIRAR 1
  FIN REPETIR

  SI N<200 ENTONCES:
    REPETIR [N] VECES:
      GIRAR -1
    FIN REPETIR
  FIN SI

FIN PROGRAMA''';

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _codeController.text = _sampleCode;
    _bt.init(_btCallbacks);
    _loadAutoSaved();
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    _typingTimer?.cancel();
    setState(() => _isTyping = true);
    _typingTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isTyping = false);
    });
    if (_compiledSuccess) {
      setState(() {
        _compiledSuccess  = false;
        _compiledLines    = [];
        _compiledFilePath = null;
        _lastErrorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _bt.dispose();
    _confettiOverlay?.remove();
    _codeController.removeListener(_onCodeChanged);
    _typingTimer?.cancel();
    _vampiritoOverlay?.remove();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BLUETOOTH
  // ─────────────────────────────────────────────────────────────

  BluetoothCallbacks get _btCallbacks => BluetoothCallbacks(
    onLog: (msg, isError) {
      debugPrint('[BT] $msg');
      if (isError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.currentLine,
          duration: const Duration(seconds: 2),
        ));
      }
    },
    onBluetoothStateChanged: (v) {
      if (mounted) setState(() => _bluetoothEnabled = v);
    },
    onDeviceFound: (d) {
      if (mounted) setState(() => _discoveredDevices.add(d));
    },
    onConnectionChanged: (_) { if (mounted) setState(() {}); },
    onScanStateChanged:  (_) { if (mounted) setState(() {}); },
  );

  void _toggleBluetoothPanel() {
    setState(() => _showBluetoothPanel = !_showBluetoothPanel);
    if (_showBluetoothPanel && _bluetoothEnabled) {
      setState(() => _discoveredDevices.clear());
      _bt.startScan(_btCallbacks, _discoveredDevices);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ARCHIVOS
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadAutoSaved() async {
    final content = await _fm.loadAutoSaved();
    if (content != null && mounted) {
      setState(() => _codeController.text = content);
    }
  }

  Future<void> _saveWithName() async {
    final currentName = _fm.currentFilePath != null
        ? _fm.currentFilePath!.split('/').last.replaceAll('.txt', '')
        : 'mi_programa';

    final nameCtrl = TextEditingController(text: currentName);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        title: const Row(children: [
          Icon(Icons.save, color: AppTheme.purple),
          SizedBox(width: 12),
          Text('Guardar archivo', style: TextStyle(color: AppTheme.foreground)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nombre del archivo:',
                style: TextStyle(color: AppTheme.comment, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.foreground),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
              decoration: InputDecoration(
                suffixText: '.txt',
                suffixStyle: const TextStyle(color: AppTheme.comment),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.comment),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.cyan),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.comment)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Guardar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    final name = nameCtrl.text.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameCtrl.dispose();
    });

    if (confirmed == true && name.isNotEmpty && mounted) {
      final fullName = name.endsWith('.txt') ? name : '$name.txt';
      final saved = await _fm.saveToFile(
        _codeController.text,
        customFileName: fullName,
      );
      if (mounted) setState(() {});
      if (mounted) {
        // --- GUARDADO EN LA NUBE (FIREBASE) ---
        final user = FirebaseAuth.instance.currentUser;
        bool cloudSaved = false;
        
        if (user != null) {
          try {
            await DatabaseService().saveProject(
              name: fullName,
              code: _codeController.text,
              obstacles: [], // TODO: Pasar obstáculos reales del Modo Bloque
            );
            cloudSaved = true;
          } catch (e) {
            debugPrint("Error guardando en la nube: $e");
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(saved ? Icons.check_circle : Icons.error,
                color: saved ? AppTheme.green : AppTheme.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(saved
                  ? (cloudSaved 
                      ? 'Guardado en dispositivo y nube ☁️' 
                      : 'Guardado localmente como "$fullName"')
                  : 'Error al guardar'),
            ),
          ]),
          backgroundColor: AppTheme.currentLine,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _openFile() async {
    final files = await _fm.listFiles();

    if (files.isEmpty) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.currentLine,
          title: const Row(children: [
            Icon(Icons.folder_open, color: AppTheme.orange),
            SizedBox(width: 12),
            Text('Sin archivos', style: TextStyle(color: AppTheme.foreground)),
          ]),
          content: const Text(
            'No hay archivos guardados todavía.\nUsa "Guardar archivo" para crear uno.',
            style: TextStyle(color: AppTheme.foreground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(color: AppTheme.cyan)),
            ),
          ],
        ),
      );
      return;
    }

    final mutableFiles = List<File>.from(files);

    if (!mounted) return;
    final selected = await showDialog<File>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AppTheme.currentLine,
          title: const Row(children: [
            Icon(Icons.folder_open, color: AppTheme.cyan),
            SizedBox(width: 12),
            Text('Abrir archivo', style: TextStyle(color: AppTheme.foreground)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: mutableFiles.isEmpty
                ? const Center(
                child: Text('No hay archivos',
                    style: TextStyle(color: AppTheme.comment)))
                : ListView.builder(
              itemCount: mutableFiles.length,
              itemBuilder: (_, i) {
                final file     = mutableFiles[i];
                final fileName = file.path.split('/').last;
                final stat     = file.statSync();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.comment.withOpacity(0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file,
                            color: AppTheme.cyan, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fileName,
                                  style: const TextStyle(
                                    color: AppTheme.foreground,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${(stat.size / 1024).toStringAsFixed(1)} KB  •  ${_fm.formatDate(stat.modified)}',
                                style: const TextStyle(
                                    color: AppTheme.comment, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Abrir',
                          icon: const Icon(Icons.folder_open,
                              color: AppTheme.green, size: 24),
                          onPressed: () => Navigator.pop(ctx, file),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete,
                              color: AppTheme.red, size: 24),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                backgroundColor: AppTheme.currentLine,
                                title: const Text('Eliminar archivo',
                                    style: TextStyle(
                                        color: AppTheme.foreground)),
                                content: Text(
                                    '¿Eliminar "$fileName"?\nEsta acción no se puede deshacer.',
                                    style: const TextStyle(
                                        color: AppTheme.foreground)),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(c, false),
                                    child: const Text('Cancelar',
                                        style: TextStyle(
                                            color: AppTheme.comment)),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        Navigator.pop(c, true),
                                    icon: const Icon(Icons.delete,
                                        size: 16),
                                    label: const Text('Eliminar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await file.delete();
                              if (_fm.currentFilePath == file.path) {
                                _fm.clear();
                                if (mounted) setState(() {});
                              }
                              setDialog(() => mutableFiles.removeAt(i));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.comment)),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      final content        = await selected.readAsString();
      _fm.currentFilePath  = selected.path;
      _fm.lastSavedContent = content;
      setState(() => _codeController.text = content);
    }
  }

  void _clearCode() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        title: const Text('Limpiar código',
            style: TextStyle(color: AppTheme.foreground)),
        content: const Text('¿Está seguro de que desea limpiar todo el código?',
            style: TextStyle(color: AppTheme.foreground)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              _codeController.clear();
              _fm.clear();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Limpiar', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareFile() async {
    if (_fm.hasUnsavedChanges(_codeController.text)) {
      await _fm.saveToFile(_codeController.text);
    }
    if (_fm.currentFilePath == null) return;
    await _fm.share(_fm.currentFilePath!);
  }

  // ─────────────────────────────────────────────────────────────
  // EJECUCIÓN
  // ─────────────────────────────────────────────────────────────

  Future<void> _executeProgram() async {
    if (_isRunning || !_codeIsValid) return;
    setState(() => _isRunning = true);

    try {
      final r        = Compilador().compilar(_codeController.text);
      final compiled = r.exito
          ? (r.salidaEjecucion ?? [])
          .where((l) =>
      l.trim().startsWith('GIRAR') ||
          l.trim().startsWith('AVANZAR'))
          .toList()
          : <String>[];

      setState(() {
        _compiledSuccess = r.exito;
        _compiledLines   = r.exito ? List<String>.from(compiled) : [];
      });

      if (r.exito && _compiledLines.isNotEmpty) {
        await _fm.deleteCompiled();
        _compiledFilePath = await _fm.saveCompiled(_compiledLines.join('\n'));
        _launchVampiritoAnimation(success: true);
      } else if (!r.exito) {
        _launchVampiritoAnimation(success: false, errorMsg: r.error);
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _sendProgram() async {
    if (_compiledLines.isEmpty || _compiledFilePath == null) return;
    if (!_bluetoothEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enciende el Bluetooth primero')));
      return;
    }
    await _fm.share(_compiledFilePath!);
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unsaved = _fm.hasUnsavedChanges(_codeController.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StemBosque IDE'),
        actions: [
          if (unsaved)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.orange),
                  ),
                  child: const Text('SIN GUARDAR',
                      style: TextStyle(
                          color: AppTheme.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
      drawer: IDEDrawer(
        hasUnsavedChanges: unsaved,
        isRunning:         _isRunning,
        bluetoothEnabled:  _bluetoothEnabled,
        currentFilePath:   _fm.currentFilePath,
        onOpenFile:        _openFile,
        onSaveFile:        _saveWithName,
        onClearCode:       _clearCode,
        onShareFile:       _shareFile,
        onToggleBluetooth: () => _bt.toggleBluetooth(onUnsupported: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth no soportado en esta plataforma')),
          );
        }),
        onOpenBlockMode: () {
          // TODO: Implementar apertura de Modo Bloque
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Modo Bloque en desarrollo...")),
          );
        },
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Toolbar(
                  onRun:     _executeProgram,
                  onClear:   _clearCode,
                  onOpen:    _openFile,
                  onSave:    _saveWithName,
                  isRunning: _isRunning,
                ),
                if (_showBluetoothPanel)
                  BluetoothPanel(
                    bluetoothEnabled:  _bluetoothEnabled,
                    isScanning:        _isScanning,
                    isConnecting:      _isConnecting,
                    devices:           _discoveredDevices,
                    connectedDevice:   _connectedDevice,
                    onToggle:          _toggleBluetoothPanel,
                    onToggleBluetooth: () => _bt.toggleBluetooth(onUnsupported: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bluetooth no soportado en esta plataforma')),
                      );
                    }),
                    onStartScan:       _startScan,
                    onStopScan:        _stopScan,
                    onOpenSettings:    () => _bt.openSettings(),
                    onDisconnect:      () => _bt.disconnect(_btCallbacks),
                    onConnect:         (d) => _bt.connect(d, _btCallbacks),
                  ),
                Expanded(
                  child: ValidatedCodeEditor(
                    controller: _codeController,
                    onValidityChanged: (isValid, errorMsg) => setState(() {
                      _codeIsValid      = isValid;
                      _lastErrorMessage = errorMsg;
                    }),
                  ),
                ),
                if (_compiledSuccess)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppTheme.currentLine.withAlpha(100),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SimulationScreen(commands: _compiledLines),
                              ),
                            ),
                            icon:  const Icon(Icons.play_circle_fill),
                            label: const Text('SIMULAR'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.purple),
                          ),
                        ),
                        if (_bluetoothEnabled) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _sendProgram,
                              icon:  const Icon(Icons.send_rounded),
                              label: const Text('ENVIAR'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.cyan),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Vampirito ─────────────────────────────────────────────
          Positioned(
            right:  16,
            bottom: _compiledSuccess ? 88 : 20,
            child: AnimatedOpacity(
              opacity:  _vampiritoAnimating ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: VampiritoPet(
                isTyping:     _isTyping,
                state:        _isRunning
                    ? VampiritoState.running
                    : _compiledSuccess
                    ? VampiritoState.success
                    : !_codeIsValid && _codeController.text.trim().isNotEmpty
                    ? VampiritoState.error
                    : _codeController.text.trim().isNotEmpty
                    ? VampiritoState.watching
                    : VampiritoState.idle,
                errorMessage: _lastErrorMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  void _launchVampiritoAnimation({
    required bool success,
    String? errorMsg,
  }) {
    _vampiritoOverlay?.remove();
    _vampiritoOverlay = null;
    setState(() => _vampiritoAnimating = true);

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => VampiritoExecutionAnimation(
        success:      success,
        errorMessage: errorMsg,
        onComplete: () {
          entry.remove();
          _vampiritoOverlay = null;
          if (mounted) {
            setState(() => _vampiritoAnimating = false);
            if (success) _launchConfetti();
          }
        },
      ),
    );
    _vampiritoOverlay = entry;
    overlay.insert(entry);
  }

  void _startScan() {
    setState(() => _discoveredDevices.clear());
    _bt.startScan(_btCallbacks, _discoveredDevices);
  }

  void _stopScan() {
    _bt.stopScan();
    setState(() {});
  }

  void _launchConfetti() {
    _confettiOverlay?.remove();
    _confettiOverlay = null;

    final overlay = Overlay.of(context);
    final entry   = OverlayEntry(builder: (_) => ConfettiWidget());
    _confettiOverlay = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 3500), () {
      entry.remove();
      if (_confettiOverlay == entry) _confettiOverlay = null;
    });
  }
}