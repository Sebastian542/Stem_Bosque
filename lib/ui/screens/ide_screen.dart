import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../bluetooth/bluetooth_manager.dart';
import '../../compiler/compiler.dart';
import '../../services/file_manager.dart';
import '../widgets/bluetooth_panel.dart';
import '../widgets/code_editor_validated.dart';
import '../widgets/execution_console.dart';
import '../widgets/ide_drawer.dart';
import '../theme/app_theme.dart';

class IDEScreen extends StatefulWidget {
  const IDEScreen({Key? key}) : super(key: key);

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {

  // ── Servicios ────────────────────────────────────────────────
  final _bt   = BluetoothManager();
  final _fm   = FileManager();

  // ── Editor ───────────────────────────────────────────────────
  final _codeController = TextEditingController();
  bool         _isRunning   = false;
  bool         _codeIsValid = false;
  bool         _showConsole = false;
  bool         _execSuccess = false;
  String?      _execError;
  List<String> _execLines   = [];

  // ── Bluetooth UI ─────────────────────────────────────────────
  bool _bluetoothEnabled   = false;
  bool _showBluetoothPanel = false;
  List<UnifiedBluetoothDevice> _discoveredDevices = [];

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
  }

  @override
  void dispose() {
    _codeController.dispose();
    _bt.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BLUETOOTH
  // ─────────────────────────────────────────────────────────────

  BluetoothCallbacks get _btCallbacks => BluetoothCallbacks(
    onLog: (msg, _) => debugPrint('[BT] $msg'),
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
          Text('Guardar archivo',
              style: TextStyle(color: AppTheme.foreground)),
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

    // Dispose seguro: después de que el dialog ya cerró
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(saved ? Icons.check_circle : Icons.error,
                color: saved ? AppTheme.green : AppTheme.red),
            const SizedBox(width: 12),
            Text(saved ? 'Guardado como "$fullName"' : 'Error al guardar'),
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
            Text('Sin archivos',
                style: TextStyle(color: AppTheme.foreground)),
          ]),
          content: const Text(
            'No hay archivos guardados todavía.\nUsa "Guardar archivo" para crear uno.',
            style: TextStyle(color: AppTheme.foreground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido',
                  style: TextStyle(color: AppTheme.cyan)),
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
            Text('Abrir archivo',
                style: TextStyle(color: AppTheme.foreground)),
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
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
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
                                    color: AppTheme.comment,
                                    fontSize: 10),
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
      final content = await selected.readAsString();
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
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.comment)),
          ),
          TextButton(
            onPressed: () {
              _codeController.clear();
              _fm.clear();
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Limpiar',
                style: TextStyle(color: AppTheme.red)),
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
    final file = File(_fm.currentFilePath!);
    if (!await file.exists()) return;
    await _fm.share(_fm.currentFilePath!);
  }

  // ─────────────────────────────────────────────────────────────
  // EJECUCIÓN
  // ─────────────────────────────────────────────────────────────

  Future<void> _executeProgram() async {
    if (_isRunning || !_codeIsValid) return;
    setState(() => _isRunning = true);
    try {
      final r = Compilador().compilar(_codeController.text);
      setState(() {
        _showConsole = true;
        _execSuccess = r.exito;
        _execError   = r.error;
        _execLines   = r.salidaEjecucion ?? [];
      });
    } catch (e) {
      setState(() {
        _showConsole = true;
        _execSuccess = false;
        _execError   = e.toString();
        _execLines   = [];
      });
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _sendProgram() async {
    if (_fm.hasUnsavedChanges(_codeController.text)) {
      await _fm.saveToFile(_codeController.text);
    }
    if (_fm.currentFilePath == null) return;
    final file = File(_fm.currentFilePath!);
    if (!await file.exists()) return;
    await _fm.share(_fm.currentFilePath!);
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unsaved = _fm.hasUnsavedChanges(_codeController.text);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('StemBosque IDE'),
            if (unsaved) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Sin guardar',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        centerTitle: false,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed:
              (_codeIsValid && !_isRunning) ? _executeProgram : null,
              icon: _isRunning
                  ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ))
                  : const Icon(Icons.play_arrow, size: 20),
              label: Text(_isRunning ? 'Ejecutando...' : 'Ejecutar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: (_codeIsValid && !_isRunning)
                    ? AppTheme.green
                    : AppTheme.comment,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
      drawer: IDEDrawer(
        hasUnsavedChanges: unsaved,
        isRunning:         _isRunning,
        bluetoothEnabled:  _bluetoothEnabled,
        showBluetoothPanel: _showBluetoothPanel,
        currentFilePath:   _fm.currentFilePath,
        onOpenFile:        _openFile,
        onSaveFile:        _saveWithName,
        onClearCode:       _clearCode,
        onShareFile:       _shareFile,
        onToggleBluetooth: _toggleBluetoothPanel,
      ),
      body: Column(
        children: [
          if (_showBluetoothPanel)
            BluetoothPanel(
              bluetoothEnabled: _bluetoothEnabled,
              isScanning:       _isScanning,
              isConnecting:     _isConnecting,
              devices:          _discoveredDevices,
              connectedDevice:  _connectedDevice,
              onToggle:         _toggleBluetoothPanel,
              onToggleBluetooth: () => _bt.toggleBluetooth(),
              onStartScan:      _startScan,
              onStopScan:       _stopScan,
              onOpenSettings:   () => _bt.openSettings(),
              onDisconnect:     () => _bt.disconnect(_btCallbacks),
              onConnect:        (d) => _bt.connect(d, _btCallbacks),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
              child: _showConsole
                  ? ExecutionConsole(
                key: const ValueKey('console'),
                lines:        _execLines,
                isSuccess:    _execSuccess,
                errorMessage: _execError,
                onSend:       _sendProgram,
                onClose: () => setState(() => _showConsole = false),
              )
                  : ValidatedCodeEditor(
                key: const ValueKey('editor'),
                controller: _codeController,
                onValidityChanged: (v) =>
                    setState(() => _codeIsValid = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startScan() {
    setState(() => _discoveredDevices.clear());
    _bt.startScan(_btCallbacks, _discoveredDevices);
  }

  void _stopScan() {
    _bt.stopScan();
    setState(() {});
  }
}