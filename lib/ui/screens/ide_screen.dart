import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
import 'block_mode_screen.dart';

class IDEScreen extends StatefulWidget {
  const IDEScreen({super.key});

  @override
  State<IDEScreen> createState() => _IDEScreenState();
}

class _IDEScreenState extends State<IDEScreen> {
  final _bt = BluetoothManager.instance;
  final _fm = FileManager.instance;

  // ── Editor ───────────────────────────────────────────────────
  late final _codeController = CodeEditorController();
  bool         _isRunning     = false;
  bool         _codeIsValid   = false;
  bool         _compiledSuccess  = false;
  OverlayEntry? _confettiOverlay;
  List<String> _compiledLines  = []; // comandos expandidos post-compilación
  String?      _compiledFilePath;          // ruta del compilado.txt guardado

  // ── Bluetooth UI ─────────────────────────────────────────────
  
  void _showUnsupportedPlatformDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.orange),
            SizedBox(width: 10),
            Text('No compatible', style: TextStyle(color: AppTheme.foreground)),
          ],
        ),
        content: const Text(
          'La conexión Bluetooth directa con el robot actualmente solo está disponible en la aplicación para dispositivos móviles (Android).\n\nEn la versión Web o Desktop puedes simular tu código o descargarlo.',
          style: TextStyle(color: AppTheme.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
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
  }

  @override
  void dispose() {
    _codeController.dispose();
    _bt.dispose();
    _confettiOverlay?.remove();
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
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || 
                  defaultTargetPlatform == TargetPlatform.linux || 
                  defaultTargetPlatform == TargetPlatform.macOS) {
      final saved = await _fm.saveToFile(_codeController.text);
      if (saved && mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Archivo guardado correctamente'),
          backgroundColor: AppTheme.green,
        ));
      }
      return;
    }

    final currentName = _fm.currentFilePath != null
        ? _fm.currentFilePath!.split('/').last.replaceAll('.txt', '')
        : 'mi_programa';

    final nameCtrl = TextEditingController(text: currentName);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.currentLine,
          title: const Row(children: [
            Icon(Icons.save, color: AppTheme.purple),
            SizedBox(width: 12),
            Text('Guardar archivo', style: TextStyle(color: AppTheme.foreground)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nombre del archivo:', style: TextStyle(color: AppTheme.comment, fontSize: 12)),
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
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Guardar')),
          ],
        ),
      );

      if (confirmed == true && nameCtrl.text.isNotEmpty && mounted) {
        final name = nameCtrl.text.trim();
        final fullName = name.endsWith('.txt') ? name : '$name.txt';
        await _fm.saveToFile(_codeController.text, customFileName: fullName);
        if (mounted) setState(() {});
      }
    } finally {
      // Pequeño retardo para evitar el error de "disposed" durante la animación de cierre
      Future.delayed(const Duration(milliseconds: 200), () {
        nameCtrl.dispose();
      });
    }
  }

  Future<void> _openFile() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || 
                  defaultTargetPlatform == TargetPlatform.linux || 
                  defaultTargetPlatform == TargetPlatform.macOS) {
      final content = await _fm.pickAndReadFile();
      if (content != null && mounted) {
        setState(() => _codeController.text = content);
      }
      return;
    }

    final files = await _fm.listFiles();
    if (files.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.currentLine,
          title: const Text('Sin archivos', style: TextStyle(color: AppTheme.foreground)),
          content: const Text('No hay archivos guardados todavía.', style: TextStyle(color: AppTheme.foreground)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
        ),
      );
      return;
    }

    if (!mounted) return;
    final selected = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        title: const Text('Abrir archivo', style: TextStyle(color: AppTheme.foreground)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (_, i) {
              final file = files[i];
              return ListTile(
                leading: const Icon(Icons.insert_drive_file, color: AppTheme.cyan),
                title: Text(file.path.split('/').last, style: const TextStyle(color: AppTheme.foreground)),
                onTap: () => Navigator.pop(ctx, file),
              );
            },
          ),
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
        title: const Text('Limpiar código', style: TextStyle(color: AppTheme.foreground)),
        content: const Text('¿Está seguro de que desea limpiar todo el código?', style: TextStyle(color: AppTheme.foreground)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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

  Future<void> _executeProgram() async {
    if (_isRunning || !_codeIsValid) return;
    setState(() => _isRunning = true);
    try {
      final r = Compilador().compilar(_codeController.text);
      final compiled = r.exito
          ? (r.salidaEjecucion ?? []).where((l) => l.trim().startsWith('GIRAR') || l.trim().startsWith('AVANZAR')).toList()
          : [];

      setState(() {
        _compiledSuccess = r.exito;
        _compiledLines   = r.exito ? List<String>.from(compiled) : [];
      });

      if (r.exito && _compiledLines.isNotEmpty) {
        await _fm.deleteCompiled();
        _compiledFilePath = await _fm.saveCompiled(_compiledLines.join('\n'));
        _launchConfetti();
      } else if (!r.exito) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(r.error ?? 'Error al compilar'),
            backgroundColor: AppTheme.red,
          ));
        }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enciende el Bluetooth primero')));
      return;
    }
    await _fm.share(_compiledFilePath!);
  }

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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.orange.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.orange),
                  ),
                  child: const Text('SIN GUARDAR', style: TextStyle(color: AppTheme.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
      drawer: IDEDrawer(
        hasUnsavedChanges: unsaved,
        isRunning: _isRunning,
        bluetoothEnabled: _bluetoothEnabled,
        currentFilePath: _fm.currentFilePath,
        onOpenFile: _openFile,
        onSaveFile: _saveWithName,
        onClearCode: _clearCode,
        onShareFile: _shareFile,
        onToggleBluetooth: () => _bt.toggleBluetooth(
          onUnsupported: () => _showUnsupportedPlatformDialog(),
        ),
        onOpenBlockMode: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BlockModeScreen()),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            Toolbar(
              onRun: _executeProgram,
              onClear: _clearCode,
              onOpen: _openFile,
              onSave: _saveWithName,
              onBluetooth: _toggleBluetoothPanel,
              isRunning: _isRunning,
              isBluetoothOpen: _showBluetoothPanel,
            ),
            
            if (_showBluetoothPanel)
              BluetoothPanel(
                bluetoothEnabled: _bluetoothEnabled,
                isScanning: _isScanning,
                isConnecting: _isConnecting,
                devices: _discoveredDevices,
                connectedDevice: _connectedDevice,
                onToggle: _toggleBluetoothPanel,
                onToggleBluetooth: () => _bt.toggleBluetooth(
                  onUnsupported: () => _showUnsupportedPlatformDialog(),
                ),
                onStartScan: _startScan,
                onStopScan: _stopScan,
                onOpenSettings: () => _bt.openSettings(),
                onDisconnect: () => _bt.disconnect(_btCallbacks),
                onConnect: (d) => _bt.connect(d, _btCallbacks),
              ),

            Expanded(
              child: ValidatedCodeEditor(
                controller: _codeController,
                onValidityChanged: (v) => setState(() => _codeIsValid = v),
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
                          MaterialPageRoute(builder: (_) => SimulationScreen(commands: _compiledLines)),
                        ),
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text('SIMULAR'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.purple),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_bluetoothEnabled)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sendProgram,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('ENVIAR'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cyan),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
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

  void _launchConfetti() {
    _confettiOverlay?.remove();
    _confettiOverlay = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => ConfettiWidget());
    _confettiOverlay = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 3500), () {
      entry.remove();
      if (_confettiOverlay == entry) _confettiOverlay = null;
    });
  }
}
