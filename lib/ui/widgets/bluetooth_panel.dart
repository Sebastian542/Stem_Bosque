import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../bluetooth/bluetooth_service.dart';

/// Panel lateral BLE — Muestra TODOS los dispositivos disponibles
class BluetoothPanel extends StatefulWidget {
  final String codeContent;
  final void Function(String message, bool isError) onLog;

  const BluetoothPanel({
    Key? key,
    required this.codeContent,
    required this.onLog,
  }) : super(key: key);

  @override
  State<BluetoothPanel> createState() => _BluetoothPanelState();
}

class _BluetoothPanelState extends State<BluetoothPanel> {
  final BleService _bt = BleService();
  final TextEditingController _fileCtrl =
  TextEditingController(text: 'programa.stb');

  List<BleDeviceInfo> _devices        = [];
  BleDeviceInfo?      _selected;
  BleDeviceInfo?      _connectedDevice;  // nombre actualizado en tiempo real
  BleConnectionState  _state     = BleConnectionState.disconnected;
  bool                _adapterOn = false;
  final List<String>  _logs      = [];

  late StreamSubscription<BleConnectionState>  _stateSub;
  late StreamSubscription<String>              _logSub;
  late StreamSubscription<BleAdapterState>     _adapterSub;
  StreamSubscription<List<BleDeviceInfo>>?     _devicesSub;
  StreamSubscription<BleDeviceInfo?>?          _connectedDevSub;

  @override
  void initState() {
    super.initState();
    _state = _bt.currentState;
    _bt.initAdapterListener();

    _stateSub = _bt.stateStream.listen(
            (s) { if (mounted) setState(() => _state = s); });

    _logSub = _bt.logStream.listen((msg) {
      if (mounted) setState(() {
        _logs.add(msg);
        if (_logs.length > 60) _logs.removeAt(0);
      });
    });

    _adapterSub = _bt.adapterStream.listen((s) {
      if (mounted) setState(() => _adapterOn = s == BleAdapterState.on);
    });

    // Nombre del dispositivo conectado — se actualiza cuando GATT resuelve el nombre
    _connectedDevSub = _bt.connectedDeviceStream.listen((info) {
      if (mounted) setState(() => _connectedDevice = info);
    });

    // Actualizar lista de dispositivos en tiempo real mientras se escanea
    _devicesSub = _bt.devicesStream.listen((list) {
      if (!mounted) return;
      setState(() {
        _devices = list;
        // Auto-seleccionar Raspberry si aún no hay selección
        if (_selected == null || !list.any((d) => d.id == _selected!.id)) {
          try {
            _selected = list.firstWhere((d) => d.isRaspberry);
          } catch (_) {
            _selected ??= list.isNotEmpty ? list.first : null;
          }
        } else {
          // Actualizar la referencia _selected si cambió el nombre
          _selected = list.firstWhere(
            (d) => d.id == _selected!.id,
            orElse: () => _selected!,
          );
        }
      });
    });

    // Al abrir el panel: verificar permisos silenciosamente y,
    // si ya están concedidos, escanear (siempre lee nombres reales).
    _bt.isBluetoothOn().then((on) async {
      if (!mounted) return;
      setState(() => _adapterOn = on);
      if (!on) return;

      final perm = await _bt.checkPermissions();
      if (perm == BlePermissionResult.granted) {
        _scan(skipRationale: true);
      }
      // Si no están concedidos, el usuario deberá pulsar el botón de radar.
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _logSub.cancel();
    _adapterSub.cancel();
    _devicesSub?.cancel();
    _connectedDevSub?.cancel();
    _fileCtrl.dispose();
    super.dispose();
  }

  // ── Diálogos de permisos ──────────────────────────────────────────────────────

  /// Muestra el rationale antes de pedir permisos por primera vez.
  Future<bool> _showRationaleDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.bluetooth, color: AppTheme.cyan, size: 22),
          SizedBox(width: 10),
          Text('Permisos Bluetooth',
              style: TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'StemBosque necesita acceso a Bluetooth y ubicación para '
              'escanear y conectar con dispositivos.\n\n'
              '• Bluetooth — conectar dispositivos BLE\n'
              '• Ubicación — requerida por Android para el escaneo BLE',
          style: TextStyle(color: AppTheme.foreground, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.comment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: AppTheme.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permitir',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ??
        false;
  }

  /// Muestra el diálogo para ir a Ajustes cuando los permisos
  /// fueron denegados permanentemente.
  Future<void> _showSettingsDialog() async {
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.currentLine,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.settings, color: AppTheme.yellow, size: 22),
          SizedBox(width: 10),
          Text('Permisos necesarios',
              style: TextStyle(
                  color: AppTheme.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'Los permisos de Bluetooth fueron denegados permanentemente.\n\n'
              'Para usar Bluetooth debes habilitarlos manualmente en\n'
              'Ajustes → Aplicaciones → StemBosque → Permisos.',
          style: TextStyle(color: AppTheme.foreground, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no',
                style: TextStyle(color: AppTheme.comment)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.yellow,
              foregroundColor: AppTheme.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir Ajustes',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ??
        false;

    if (go) await _bt.openSettings();
  }

  // ── Acciones ──────────────────────────────────────────────────────────────────

  Future<void> _scan({bool skipRationale = false}) async {
    if (!_adapterOn) {
      _addLog('✗ Bluetooth desactivado');
      return;
    }

    // 1. Verificar permisos
    final perm = await _bt.checkPermissions();
    if (perm != BlePermissionResult.granted && !skipRationale) {
      final accepted = await _showRationaleDialog();
      if (!accepted || !mounted) return;
    }

    // 2. Solicitar permisos al SO
    final result = await _bt.requestPermissions();

    if (!mounted) return;

    if (result == BlePermissionResult.permanentlyDenied) {
      await _showSettingsDialog();
      return;
    }
    if (result == BlePermissionResult.denied) {
      _addLog('✗ Permisos denegados por el usuario');
      return;
    }

    // 3. Permisos concedidos → iniciar escaneo.
    // La lista se actualiza en tiempo real vía devicesStream (ver initState).
    await _bt.scan(seconds: 10, autoDeepScan: false);
  }

  Future<void> _deepScan({bool skipRationale = false}) async {
    if (!_adapterOn) {
      _addLog('✗ Bluetooth desactivado');
      return;
    }

    // Ya tenemos permisos si llegamos aquí, hacer escaneo profundo
    final list = await _bt.deepScan(seconds: 10);
    if (!mounted) return;
    setState(() {
      _devices = list;
      try {
        _selected = list.firstWhere((d) => d.isRaspberry);
      } catch (_) {
        _selected = list.isNotEmpty ? list.first : null;
      }
    });
  }

  Future<void> _toggleConnect() async {
    if (_bt.isConnected) {
      setState(() => _connectedDevice = null);
      await _bt.disconnect();
    } else {
      if (_selected == null) {
        _addLog('✗ Selecciona un dispositivo');
        return;
      }
      final res = await _bt.connect(_selected!);
      if (!res.success) widget.onLog('BLE: ${res.message}', true);
    }
  }

  Future<void> _send() async {
    if (!_bt.isConnected) {
      _addLog('✗ Conéctate primero');
      return;
    }
    final name = _fileCtrl.text.trim().isEmpty
        ? 'programa.stb'
        : _fileCtrl.text.trim();
    final res = await _bt.sendProgram(widget.codeContent, name);
    widget.onLog(
      res.success
          ? '✓ BT: "$name" enviado a ${_bt.connectedDeviceInfo?.name}'
          : '✗ BT: ${res.message}',
      !res.success,
    );
  }

  void _addLog(String msg) => setState(() {
    _logs.add(msg);
    if (_logs.length > 60) _logs.removeAt(0);
  });

  // ── Build ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 282,
      decoration: const BoxDecoration(
        color: Color(0xFF1e1f29),
        border: Border(left: BorderSide(color: AppTheme.currentLine, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAdapterBanner(),
                  _buildStatusCard(),
                  const SizedBox(height: 12),
                  _buildDeviceSection(),
                  const SizedBox(height: 12),
                  _buildConnectButton(),
                  const SizedBox(height: 16),
                  _buildSendSection(),
                  const SizedBox(height: 12),
                  _buildLog(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cabecera ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFF1a1b26),
        border: Border(bottom: BorderSide(color: AppTheme.currentLine)),
      ),
      child: Row(children: [
        Icon(Icons.bluetooth,
            color: _bt.isConnected ? AppTheme.cyan : AppTheme.comment,
            size: 18),
        const SizedBox(width: 8),
        const Text('Bluetooth BLE',
            style: TextStyle(
                color: AppTheme.foreground,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4)),
        const Spacer(),
        _dot(_stateColor),
      ]),
    );
  }

  Widget _dot(Color c) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  // ── Banner adaptador ───────────────────────────────────────────────────────────
  Widget _buildAdapterBanner() {
    if (_adapterOn) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.red.withOpacity(0.5)),
      ),
      child: Row(children: [
        const Icon(Icons.bluetooth_disabled, color: AppTheme.red, size: 16),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Bluetooth apagado',
              style: TextStyle(color: AppTheme.red, fontSize: 11)),
        ),
        GestureDetector(
          onTap: _bt.turnOn,
          child: const Text('Activar',
              style: TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ── Tarjeta de estado ──────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _stateColor.withOpacity(0.45)),
      ),
      child: Row(children: [
        Icon(_stateIcon, color: _stateColor, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_stateText,
              style: TextStyle(
                  color: _stateColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  // ── Sección dispositivos — LISTA EXPANDIBLE ────────────────────────────────────
  Widget _buildDeviceSection() {
    final scanning = _state == BleConnectionState.scanning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('DISPOSITIVOS (${_devices.length})', style: _labelStyle),
            Row(
              children: [
                // Botón para actualizar nombres (escaneo profundo)
                if (_devices.isNotEmpty)
                  GestureDetector(
                    onTap: (scanning || _bt.isConnected) ? null : _deepScan,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Tooltip(
                        message: 'Actualizar nombres (conecta a cada dispositivo)',
                        child: Icon(
                          Icons.refresh,
                          color: _bt.isConnected || scanning
                              ? AppTheme.comment
                              : AppTheme.green,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                if (_devices.isNotEmpty) const SizedBox(width: 8),
                // Botón de escaneo principal
                GestureDetector(
                  onTap: (scanning || _bt.isConnected) ? null : _scan,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: scanning
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.cyan))
                        : Tooltip(
                            message: 'Buscar dispositivos',
                            child: Icon(Icons.radar,
                                color: _bt.isConnected
                                    ? AppTheme.comment
                                    : AppTheme.cyan,
                                size: 16),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_devices.isEmpty && !scanning)
          _buildEmptyDevices()
        else
          _buildDeviceList(),
      ],
    );
  }

  Widget _buildEmptyDevices() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.currentLine),
      ),
      child: const Column(children: [
        Icon(Icons.search_off, color: AppTheme.comment, size: 22),
        SizedBox(height: 5),
        Text('Sin dispositivos',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.comment, fontSize: 11)),
        SizedBox(height: 2),
        Text('Pulsa el radar para buscar',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.comment, fontSize: 9)),
      ]),
    );
  }

  // ── LISTA DE DISPOSITIVOS (en lugar de dropdown) ───────────────────────────────
  Widget _buildDeviceList() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: _devices.length > 5 ? 200 : _devices.length * 48.0,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.currentLine),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _devices.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: AppTheme.currentLine.withOpacity(0.3),
        ),
        itemBuilder: (context, index) {
          final device = _devices[index];
          final isSelected = _selected?.id == device.id;
          final isConnected = _bt.connectedDeviceInfo?.id == device.id;

          return InkWell(
            onTap: _bt.isConnected ? null : () {
              setState(() => _selected = device);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: isSelected
                  ? AppTheme.cyan.withOpacity(0.1)
                  : Colors.transparent,
              child: Row(
                children: [
                  // Icono según tipo de dispositivo
                  Icon(
                    _getDeviceIcon(device),
                    color: _getDeviceColor(device),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  // Info del dispositivo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          device.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getDeviceColor(device),
                            fontWeight: device.isRaspberry || isConnected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (device.rssi != 0)
                          Row(
                            children: [
                              Icon(
                                _getSignalIcon(device.rssi),
                                color: _getSignalColor(device.rssi),
                                size: 10,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${device.rssi} dBm',
                                style: TextStyle(
                                  color: _getSignalColor(device.rssi),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Indicador de selección/conexión
                  if (isConnected)
                    const Icon(Icons.check_circle, color: AppTheme.green, size: 14)
                  else if (isSelected)
                    const Icon(Icons.radio_button_checked, color: AppTheme.cyan, size: 14)
                  else
                    const Icon(Icons.radio_button_unchecked, color: AppTheme.comment, size: 14),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers para iconos y colores ──────────────────────────────────────────────

  IconData _getDeviceIcon(BleDeviceInfo device) {
    final name = device.name.toLowerCase();

    if (device.isRaspberry) return Icons.memory;

    // Teléfonos y tablets
    if (name.contains('iphone') || name.contains('ipad') ||
        name.contains('pixel') || name.contains('samsung') ||
        name.contains('galaxy') || name.contains('android') ||
        name.contains('xiaomi') || name.contains('huawei') ||
        name.contains('motorola') || name.contains('oppo') ||
        name.contains('oneplus') || name.contains('realme') ||
        name.contains('sony') || name.contains('lg') ||
        name.contains('teléfono') || name.contains('tablet')) {
      return Icons.phone_android;
    }
    // PCs y laptops
    if (name.contains('mac') || name.contains('pc') ||
        name.contains('surface') || name.contains('laptop') ||
        name.contains('microsoft') || name.contains('dell') ||
        name.contains('hp') || name.contains('lenovo') ||
        name.contains('asus') || name.contains('book')) {
      return Icons.laptop;
    }
    // Audio
    if (name.contains('auricular') || name.contains('altavoz') ||
        name.contains('headphone') || name.contains('buds') ||
        name.contains('airpod') || name.contains('speaker') ||
        name.contains('bose') || name.contains('sony')) {
      return Icons.headphones;
    }
    // Wearables
    if (name.contains('watch') || name.contains('wearable') ||
        name.contains('fitness') || name.contains('garmin') ||
        name.contains('fitbit')) {
      return Icons.watch;
    }
    // HID
    if (name.contains('teclado') || name.contains('ratón') ||
        name.contains('hid')) {
      return Icons.keyboard;
    }

    return Icons.bluetooth;
  }

  Color _getDeviceColor(BleDeviceInfo device) {
    if (device.isRaspberry) return AppTheme.green;
    if (_bt.connectedDeviceInfo?.id == device.id) return AppTheme.green;
    return AppTheme.foreground;
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -50) return Icons.signal_cellular_4_bar;
    if (rssi >= -70) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return AppTheme.green;
    if (rssi >= -70) return AppTheme.yellow;
    return AppTheme.red;
  }

  // ── Botón conectar / desconectar ───────────────────────────────────────────────
  Widget _buildConnectButton() {
    final busy = _state == BleConnectionState.connecting ||
        _state == BleConnectionState.scanning;
    final connected = _bt.isConnected;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: busy ? null : _toggleConnect,
        icon: busy
            ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.background))
            : Icon(
            connected ? Icons.bluetooth_connected : Icons.bluetooth,
            size: 15),
        label: Text(
          busy
              ? (_state == BleConnectionState.scanning
              ? 'Escaneando...'
              : 'Conectando...')
              : connected
              ? 'Desconectar'
              : 'Conectar',
          style:
          const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: connected ? AppTheme.red : AppTheme.cyan,
          foregroundColor: AppTheme.background,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ── Sección envío ──────────────────────────────────────────────────────────────
  Widget _buildSendSection() {
    final canSend = _bt.isConnected &&
        _state != BleConnectionState.transferring;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ENVIAR PROGRAMA', style: _labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: _fileCtrl,
          style: const TextStyle(
              color: AppTheme.foreground,
              fontSize: 12,
              fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            hintText: 'programa.stb',
            hintStyle:
            const TextStyle(color: AppTheme.comment, fontSize: 11),
            labelText: 'Nombre del archivo',
            labelStyle:
            const TextStyle(color: AppTheme.comment, fontSize: 10),
            filled: true,
            fillColor: AppTheme.background,
            prefixIcon: const Icon(Icons.insert_drive_file,
                color: AppTheme.comment, size: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.currentLine),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppTheme.cyan),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canSend ? _send : null,
            icon: _state == BleConnectionState.transferring
                ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.background))
                : const Icon(Icons.send, size: 15),
            label: Text(
              _state == BleConnectionState.transferring
                  ? 'Enviando...'
                  : 'Enviar a Raspberry Pi',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              canSend ? AppTheme.green : AppTheme.currentLine,
              foregroundColor: AppTheme.background,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: canSend ? 2 : 0,
            ),
          ),
        ),
        if (_bt.isConnected) ...[
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.info_outline,
                color: AppTheme.comment, size: 11),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Destino: ${_connectedDevice?.name ?? _bt.connectedDeviceInfo?.name ?? "dispositivo"}',
                style:
                const TextStyle(color: AppTheme.comment, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ],
      ],
    );
  }

  // ── Log ────────────────────────────────────────────────────────────────────────
  Widget _buildLog() {
    if (_logs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('LOG BLE', style: _labelStyle),
            GestureDetector(
              onTap: () => setState(() => _logs.clear()),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.clear_all,
                    color: AppTheme.comment, size: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 130,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.currentLine),
          ),
          child: ListView.builder(
            itemCount: _logs.length,
            reverse: true,
            itemBuilder: (_, i) {
              final msg = _logs[_logs.length - 1 - i];
              return Text(msg,
                  style: TextStyle(
                    color: msg.contains('✗')
                        ? AppTheme.red
                        : msg.contains('✓')
                        ? AppTheme.green
                        : msg.contains('⚠')
                        ? AppTheme.yellow
                        : AppTheme.foreground.withOpacity(0.75),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ));
            },
          ),
        ),
      ],
    );
  }

  // ── Helpers de estado ──────────────────────────────────────────────────────────
  Color get _stateColor {
    switch (_state) {
      case BleConnectionState.connected:    return AppTheme.green;
      case BleConnectionState.connecting:   return AppTheme.yellow;
      case BleConnectionState.scanning:     return AppTheme.orange;
      case BleConnectionState.transferring: return AppTheme.cyan;
      case BleConnectionState.error:        return AppTheme.red;
      case BleConnectionState.disconnected: return AppTheme.comment;
    }
  }

  IconData get _stateIcon {
    switch (_state) {
      case BleConnectionState.connected:    return Icons.bluetooth_connected;
      case BleConnectionState.connecting:   return Icons.bluetooth_searching;
      case BleConnectionState.scanning:     return Icons.radar;
      case BleConnectionState.transferring: return Icons.sync;
      case BleConnectionState.error:        return Icons.error_outline;
      case BleConnectionState.disconnected: return Icons.bluetooth_disabled;
    }
  }

  String get _stateText {
    switch (_state) {
      case BleConnectionState.connected:
        return 'Conectado · ${_connectedDevice?.name ?? _bt.connectedDeviceInfo?.name ?? ""}';
      case BleConnectionState.connecting:   return 'Conectando...';
      case BleConnectionState.scanning:     return 'Escaneando...';
      case BleConnectionState.transferring: return 'Enviando archivo...';
      case BleConnectionState.error:        return 'Error de conexión';
      case BleConnectionState.disconnected: return 'Desconectado';
    }
  }

  static const _labelStyle = TextStyle(
    color: AppTheme.comment,
    fontSize: 10,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w600,
  );
}