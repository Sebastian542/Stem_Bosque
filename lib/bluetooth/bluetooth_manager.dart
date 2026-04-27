import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
as classic;
import 'package:permission_handler/permission_handler.dart';

import 'bluetooth_device.dart';

export 'bluetooth_device.dart';

/// Callbacks que BluetoothManager usa para notificar a la UI
class BluetoothCallbacks {
  final void Function(String message, bool isError) onLog;
  final void Function(bool enabled) onBluetoothStateChanged;
  final void Function(UnifiedBluetoothDevice device) onDeviceFound;
  final void Function(UnifiedBluetoothDevice? device) onConnectionChanged;
  final void Function(bool scanning) onScanStateChanged;

  const BluetoothCallbacks({
    required this.onLog,
    required this.onBluetoothStateChanged,
    required this.onDeviceFound,
    required this.onConnectionChanged,
    required this.onScanStateChanged,
  });
}

class BluetoothManager {
  static final BluetoothManager instance = BluetoothManager._internal();
  BluetoothManager._internal();

  // ── Estado interno ───────────────────────────────────────────
  BluetoothAdapterState _bleState = BluetoothAdapterState.unknown;
  classic.BluetoothConnection? _classicConnection;
  UnifiedBluetoothDevice? _connectedDevice;

  bool _isScanning    = false;
  bool _isConnecting  = false;
  bool _bluetoothEnabled = false;
  int  _reconnectAttempts = 0;

  static const int _maxReconnectAttempts = 3;

  // ── Subscripciones ──────────────────────────────────────────
  StreamSubscription<BluetoothAdapterState>? _bleSubscription;
  StreamSubscription<List<ScanResult>>? _bleScanSubscription;
  StreamSubscription<classic.BluetoothState>? _classicSubscription;
  Timer? _reconnectTimer;
  Timer? _connectionTimeoutTimer;

  // ── Getters públicos ────────────────────────────────────────
  bool get bluetoothEnabled  => _bluetoothEnabled;
  bool get isScanning        => _isScanning;
  bool get isConnecting      => _isConnecting;
  UnifiedBluetoothDevice? get connectedDevice => _connectedDevice;

  // ── Init y dispose ──────────────────────────────────────────

  Future<void> init(BluetoothCallbacks cb) async {
    await _requestPermissions();

    // BLE
    _bleSubscription = FlutterBluePlus.adapterState.listen((state) {
      _bleState = state;
      _bluetoothEnabled = state == BluetoothAdapterState.on;
      cb.onBluetoothStateChanged(_bluetoothEnabled);
    });
    _bleState = await FlutterBluePlus.adapterState.first;

    // Clásico
    _classicSubscription =
        classic.FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
          _bluetoothEnabled = state == classic.BluetoothState.STATE_ON;
          cb.onBluetoothStateChanged(_bluetoothEnabled);
        });

    final classicState =
    await classic.FlutterBluetoothSerial.instance.state;
    _bluetoothEnabled = classicState == classic.BluetoothState.STATE_ON ||
        _bleState == BluetoothAdapterState.on;
    cb.onBluetoothStateChanged(_bluetoothEnabled);
  }

  void dispose() {
    _bleSubscription?.cancel();
    _bleScanSubscription?.cancel();
    _classicSubscription?.cancel();
    _reconnectTimer?.cancel();
    _connectionTimeoutTimer?.cancel();
    _cleanup();
  }

  // ── Permisos ────────────────────────────────────────────────

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.bluetooth,
      Permission.storage,
    ].request();
  }

  // ── Toggle Bluetooth ────────────────────────────────────────

  Future<void> toggleBluetooth({required VoidCallback onUnsupported}) async {
    if (kIsWeb) {
      onUnsupported();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // En PC abrimos la configuración del sistema directamente
      await openSettings();
      return;
    }

    if (_bluetoothEnabled) {
      await classic.FlutterBluetoothSerial.instance.requestDisable();
    } else {
      await classic.FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  Future<void> openSettings() async {
    await classic.FlutterBluetoothSerial.instance.openSettings();
  }

  // ── Escaneo ─────────────────────────────────────────────────

  Future<void> startScan(
      BluetoothCallbacks cb,
      List<UnifiedBluetoothDevice> currentDevices,
      ) async {
    if (_isScanning || !_bluetoothEnabled) return;

    _isScanning = true;
    cb.onScanStateChanged(true);
    cb.onLog('🔍 Escaneando dispositivos Bluetooth...', false);

    try {
      // Vinculados clásicos
      final bonded =
      await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      for (final d in bonded) {
        cb.onDeviceFound(UnifiedBluetoothDevice(
          name: d.name ?? '',
          address: d.address,
          type: BluetoothDeviceType.classic,
          classicDevice: d,
        ));
      }
      cb.onLog('✓ ${bonded.length} dispositivos clásicos vinculados', false);

      // Descubrimiento clásico
      cb.onLog('⏳ Buscando dispositivos cercanos...', false);
      StreamSubscription<classic.BluetoothDiscoveryResult>? discoverySub;
      discoverySub = classic.FlutterBluetoothSerial.instance
          .startDiscovery()
          .listen((result) {
        final exists = currentDevices
            .any((d) => d.address == result.device.address);
        if (!exists) {
          final device = UnifiedBluetoothDevice(
            name: result.device.name ?? '',
            address: result.device.address,
            type: BluetoothDeviceType.classic,
            rssi: result.rssi,
            classicDevice: result.device,
          );
          cb.onDeviceFound(device);
          cb.onLog('  → ${device.displayName}', false);
        }
      });

      await Future.delayed(const Duration(seconds: 12));
      await discoverySub.cancel();

      // BLE
      _bleScanSubscription?.cancel();
      _bleScanSubscription =
          FlutterBluePlus.scanResults.listen((results) {
            for (final r in results) {
              final exists = currentDevices.any((d) =>
              d.type == BluetoothDeviceType.ble &&
                  d.bleDevice?.remoteId == r.device.remoteId);
              if (!exists) {
                cb.onDeviceFound(UnifiedBluetoothDevice(
                  name: r.device.platformName,
                  address: r.device.remoteId.toString(),
                  type: BluetoothDeviceType.ble,
                  rssi: r.rssi,
                  bleDevice: r.device,
                ));
              }
            }
          });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();

      cb.onLog(
          '✓ Escaneo completado: ${currentDevices.length} dispositivos', false);
    } catch (e) {
      cb.onLog('✗ Error al escanear: $e', true);
    } finally {
      _isScanning = false;
      cb.onScanStateChanged(false);
    }
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _isScanning = false;
  }

  // ── Conexión ─────────────────────────────────────────────────

  bool isAudioDevice(UnifiedBluetoothDevice device) {
    final name = device.name.toLowerCase();
    const keywords = [
      'airpods', 'buds', 'earbuds', 'headphone', 'headset',
      'speaker', 'soundbar', 'jbl', 'bose', 'sony', 'beats',
      'audio', 'sound', 'music', 'galaxy buds', 'xiaomi buds',
      'redmi buds', 'freebuds', 'audifonos',
    ];
    return keywords.any((k) => name.contains(k));
  }

  Future<void> connect(
      UnifiedBluetoothDevice device,
      BluetoothCallbacks cb,
      ) async {
    if (_isConnecting) {
      cb.onLog('⚠ Ya hay una conexión en proceso...', false);
      return;
    }
    _isConnecting = true;
    _reconnectAttempts = 0;

    try {
      await _connectInternal(device, cb);
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _connectInternal(
      UnifiedBluetoothDevice device,
      BluetoothCallbacks cb,
      ) async {
    try {
      cb.onLog('🔌 Conectando a ${device.displayName}...', false);

      if (device.type == BluetoothDeviceType.ble) {
        await device.bleDevice!
            .connect(timeout: const Duration(seconds: 15));
        _connectedDevice = device;
        cb.onConnectionChanged(device);
        cb.onLog('✓ Conectado (BLE): ${device.displayName}', false);
        return;
      }

      // ── Bluetooth Clásico ──────────────────────────────────
      cb.onLog('  📋 Limpiando conexiones previas...', false);
      await _cleanup();
      await Future.delayed(const Duration(milliseconds: 1500));

      cb.onLog('  📋 Verificando emparejamiento...', false);
      var bonded =
      await classic.FlutterBluetoothSerial.instance.getBondedDevices();
      classic.BluetoothDevice? target = bonded
          .cast<classic.BluetoothDevice?>()
          .firstWhere((d) => d?.address == device.address, orElse: () => null);

      if (target == null) {
        cb.onLog('  ⚠ Emparejando dispositivo...', false);
        final paired = await classic.FlutterBluetoothSerial.instance
            .bondDeviceAtAddress(device.address)
            .timeout(const Duration(seconds: 30), onTimeout: () => false);

        if (paired != true) {
          throw Exception('Emparejamiento cancelado o rechazado');
        }

        cb.onLog('  ✓ Emparejamiento exitoso', false);
        await Future.delayed(const Duration(seconds: 5));

        bonded =
        await classic.FlutterBluetoothSerial.instance.getBondedDevices();
        target = bonded
            .cast<classic.BluetoothDevice?>()
            .firstWhere((d) => d?.address == device.address,
            orElse: () => null);

        if (target == null) throw Exception('Dispositivo no encontrado tras emparejar');
      } else {
        cb.onLog('  ✓ Ya emparejado', false);
      }

      cb.onLog('  📋 Estableciendo conexión SPP...', false);
      bool connected = false;

      _connectionTimeoutTimer =
          Timer(const Duration(seconds: 30), () {
            if (!connected) cb.onLog('  ⏱ Timeout (30s)', true);
          });

      classic.BluetoothConnection connection;
      try {
        connection = await classic.BluetoothConnection.toAddress(device.address)
            .timeout(const Duration(seconds: 30),
            onTimeout: () =>
            throw TimeoutException('Timeout de conexión'));
      } on TimeoutException {
        _connectionTimeoutTimer?.cancel();
        throw Exception('El dispositivo no respondió en 30 segundos');
      } catch (e) {
        _connectionTimeoutTimer?.cancel();
        final msg = e.toString().toLowerCase();
        if (msg.contains('read failed') ||
            msg.contains('socket might closed') ||
            msg.contains('socket closed')) {
          throw Exception(
              'El dispositivo rechazó la conexión.\n'
                  '• No tiene servidor SPP activo\n'
                  '• Está ocupado con otra conexión');
        }
        rethrow;
      }

      _connectionTimeoutTimer?.cancel();
      connected = true;

      await Future.delayed(const Duration(milliseconds: 500));
      if (!connection.isConnected) {
        connection.dispose();
        throw Exception('Conexión establecida pero no activa');
      }

      _classicConnection = connection;
      _connectedDevice = UnifiedBluetoothDevice(
        name: target.name ?? device.name,
        address: target.address,
        type: BluetoothDeviceType.classic,
        classicDevice: target,
      );

      cb.onConnectionChanged(_connectedDevice);
      cb.onLog('✓ Conectado: ${_connectedDevice!.displayName}', false);
      cb.onLog('  Tipo: Bluetooth Clásico (SPP)', false);

      _reconnectAttempts = 0;
      _monitorConnection(cb);
    } catch (e) {
      await _cleanup();
      cb.onConnectionChanged(null);
      cb.onLog('✗ Error de conexión: $e', true);

      // Reintentar si aplica
      if (_reconnectAttempts < _maxReconnectAttempts &&
          !isAudioDevice(device)) {
        _reconnectAttempts++;
        cb.onLog(
            '🔄 Reintentando ($_reconnectAttempts/$_maxReconnectAttempts)...',
            false);
        await Future.delayed(Duration(seconds: 3 * _reconnectAttempts));
        await _connectInternal(device, cb);
      }
    }
  }

  void _monitorConnection(BluetoothCallbacks cb) {
    _reconnectTimer?.cancel();
    _reconnectTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
          if (_classicConnection != null &&
              !_classicConnection!.isConnected) {
            cb.onLog('⚠ Conexión perdida', true);
            timer.cancel();
            _connectedDevice = null;
            cb.onConnectionChanged(null);
            _cleanup();
          }
        });
  }

  Future<void> disconnect(BluetoothCallbacks cb) async {
    try {
      _reconnectTimer?.cancel();
      _connectionTimeoutTimer?.cancel();

      if (_connectedDevice?.type == BluetoothDeviceType.ble) {
        await _connectedDevice!.bleDevice!.disconnect();
      } else {
        await _cleanup();
      }
      _connectedDevice = null;
      cb.onConnectionChanged(null);
      cb.onLog('Desconectado', false);
    } catch (e) {
      cb.onLog('Error al desconectar: $e', true);
    }
  }

  Future<void> _cleanup() async {
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

  // ── Envío de archivo ─────────────────────────────────────────

  Future<void> sendFile(String content, BluetoothCallbacks cb) async {
    if (_connectedDevice == null) {
      throw Exception('No hay dispositivo conectado');
    }

    cb.onLog('📤 Enviando archivo...', false);
    cb.onLog('  Dispositivo: ${_connectedDevice!.displayName}', false);

    if (_connectedDevice!.type == BluetoothDeviceType.ble) {
      await _sendBLE(content, cb);
    } else {
      await _sendClassic(content, cb);
    }
  }

  Future<void> _sendBLE(String content, BluetoothCallbacks cb) async {
    cb.onLog('🔍 Descubriendo servicios BLE...', false);
    final services =
    await _connectedDevice!.bleDevice!.discoverServices();

    BluetoothCharacteristic? writeChar;
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.write) { writeChar = c; break; }
      }
      if (writeChar != null) break;
    }

    if (writeChar == null) {
      throw Exception('No se encontró característica de escritura BLE');
    }

    final bytes = utf8.encode(content);
    final totalChunks = (bytes.length / 20).ceil();
    cb.onLog('📊 ${bytes.length} bytes en $totalChunks paquetes', false);

    for (int i = 0; i < bytes.length; i += 20) {
      final end = (i + 20 < bytes.length) ? i + 20 : bytes.length;
      await writeChar.write(bytes.sublist(i, end), withoutResponse: false);
      final chunk = (i ~/ 20) + 1;
      if (chunk % 10 == 0) cb.onLog('  Progreso: $chunk/$totalChunks', false);
      await Future.delayed(const Duration(milliseconds: 50));
    }

    cb.onLog('✓ Envío BLE completado', false);
  }

  Future<void> _sendClassic(String content, BluetoothCallbacks cb) async {
    if (_classicConnection == null || !_classicConnection!.isConnected) {
      throw Exception('Conexión Bluetooth Clásica perdida');
    }

    final bytes = utf8.encode(content);
    cb.onLog('📊 ${bytes.length} bytes a enviar', false);

    _classicConnection!.output.add(Uint8List.fromList(bytes));
    cb.onLog('⏳ Esperando confirmación...', false);
    await _classicConnection!.output.allSent;

    if (!_classicConnection!.isConnected) {
      throw Exception('Conexión perdida durante la transmisión');
    }

    cb.onLog('✓ Envío clásico completado', false);
  }
}
