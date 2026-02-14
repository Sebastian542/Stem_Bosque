import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';

// ── UUIDs Nordic UART Service (NUS) ──────────────────────────────────────────
const String _kNusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const String _kNusTxCharUuid  = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

// ── Tipos públicos ────────────────────────────────────────────────────────────
enum BleConnectionState { disconnected, scanning, connecting, connected, transferring, error }
enum BleAdapterState    { on, off, unavailable }
enum BlePermissionResult { granted, denied, permanentlyDenied }

class BleResult {
  final bool   success;
  final String message;
  const BleResult({required this.success, required this.message});
}

class BleDeviceInfo {
  final String id;
  final String name;
  final int    rssi;
  final fbp.BluetoothDevice _device;

  const BleDeviceInfo._({
    required this.id,
    required this.name,
    required this.rssi,
    required fbp.BluetoothDevice device,
  }) : _device = device;

  bool get isRaspberry =>
      name.toLowerCase().contains('raspberry') ||
      name.toLowerCase().contains('raspi')     ||
      name.toLowerCase().contains('stembosque');
}

// ── Servicio BLE ──────────────────────────────────────────────────────────────
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  fbp.BluetoothDevice?         _device;
  fbp.BluetoothCharacteristic? _txChar;
  StreamSubscription?          _connSub;
  StreamSubscription?          _adapterSub;
  BleDeviceInfo?               _connectedInfo;

  final _stateCtrl        = StreamController<BleConnectionState>.broadcast();
  final _logCtrl          = StreamController<String>.broadcast();
  final _adapterCtrl      = StreamController<BleAdapterState>.broadcast();
  final _devicesCtrl      = StreamController<List<BleDeviceInfo>>.broadcast();
  final _connectedDevCtrl = StreamController<BleDeviceInfo?>.broadcast();
  final _liveDevices      = <String, BleDeviceInfo>{};

  BleConnectionState _state = BleConnectionState.disconnected;

  Stream<BleConnectionState>  get stateStream          => _stateCtrl.stream;
  Stream<String>              get logStream            => _logCtrl.stream;
  Stream<BleAdapterState>     get adapterStream        => _adapterCtrl.stream;
  Stream<List<BleDeviceInfo>> get devicesStream        => _devicesCtrl.stream;
  Stream<BleDeviceInfo?>      get connectedDeviceStream => _connectedDevCtrl.stream;
  BleConnectionState          get currentState         => _state;
  BleDeviceInfo?              get connectedDeviceInfo  => _connectedInfo;

  bool get isConnected =>
      _state == BleConnectionState.connected ||
      _state == BleConnectionState.transferring;

  void _setState(BleConnectionState s) { _state = s; _stateCtrl.add(s); }
  void _log(String msg)                => _logCtrl.add(msg);

  void _setConnectedInfo(BleDeviceInfo? info) {
    _connectedInfo = info;
    _connectedDevCtrl.add(info);
  }

  void _upsertDevice(BleDeviceInfo d) {
    _liveDevices[d.id] = d;
    final sorted = _liveDevices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    _devicesCtrl.add(List.unmodifiable(sorted));
  }

  // ── Adaptador ────────────────────────────────────────────────────────────────
  void initAdapterListener() {
    _adapterSub?.cancel();
    _adapterSub = fbp.FlutterBluePlus.adapterState.listen((s) {
      _adapterCtrl.add(s == fbp.BluetoothAdapterState.on
          ? BleAdapterState.on : BleAdapterState.off);
    });
  }

  Future<bool> isBluetoothOn() async =>
      await fbp.FlutterBluePlus.adapterState.first == fbp.BluetoothAdapterState.on;

  Future<void> turnOn() async => fbp.FlutterBluePlus.turnOn();

  // ── Permisos ──────────────────────────────────────────────────────────────────
  Future<BlePermissionResult> checkPermissions() async {
    for (final p in [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse]) {
      final s = await p.status;
      if (s.isPermanentlyDenied) return BlePermissionResult.permanentlyDenied;
      if (!s.isGranted)          return BlePermissionResult.denied;
    }
    return BlePermissionResult.granted;
  }

  Future<BlePermissionResult> requestPermissions() async {
    _log('Solicitando permisos...');
    final perms = [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse];
    for (final p in perms) {
      if (await p.isPermanentlyDenied) return BlePermissionResult.permanentlyDenied;
    }
    final results = await perms.request();
    for (final e in results.entries) {
      if (e.value.isPermanentlyDenied) return BlePermissionResult.permanentlyDenied;
      if (!e.value.isGranted)          return BlePermissionResult.denied;
    }
    _log('✓ Permisos concedidos');
    return BlePermissionResult.granted;
  }

  Future<void> openSettings() => openAppSettings();

  // ── Resolver nombre sin conectarse ────────────────────────────────────────────
  String _resolveDeviceName({
    required String mac,
    required String platformName,
    required String advName,
    required Map<int, List<int>> manufacturerData,
    required List<String> serviceUuids,
  }) {
    if (platformName.isNotEmpty) return platformName;
    if (advName.isNotEmpty)      return advName;

    final existing = _liveDevices[mac]?.name ?? '';
    if (existing.isNotEmpty && !existing.startsWith('Dispositivo')) return existing;

    const mfr = <int, String>{
      0x004C: 'iPhone / iPad',
      0x0075: 'Samsung Galaxy', 0x06F5: 'Samsung Galaxy',
      0x0006: 'Microsoft',      0x0621: 'Microsoft',
      0x05A7: 'Google Pixel',   0x00E0: 'Google / LG',
      0x0157: 'Xiaomi',         0x038F: 'Xiaomi',   0x07B2: 'Xiaomi',
      0x007B: 'Huawei',         0x03AF: 'Huawei',
      0x05D6: 'OPPO/OnePlus',   0x066D: 'OPPO/OnePlus',
      0x012D: 'Sony',           0x054C: 'Sony',
      0x0243: 'LG',             0x008D: 'Motorola',
      0x0187: 'Lenovo',         0x0118: 'HP',
      0x00DC: 'Dell',           0x04F8: 'ASUS',
      0x0059: 'Nordic (nRF)',
    };
    for (final id in manufacturerData.keys) {
      if (mfr.containsKey(id)) return mfr[id]!;
    }

    if (serviceUuids.any((u) => u.contains('6e400001'))) return 'StemBosque';
    if (serviceUuids.any((u) => u.contains('fd6f') || u.contains('fe9f'))) return 'iPhone / iPad';
    if (serviceUuids.any((u) => u.contains('fe2c') || u.contains('fd5a'))) return 'Android';
    if (serviceUuids.any((u) => u.contains('fe6f')))  return 'Samsung Galaxy';
    if (serviceUuids.any((u) => u.contains('1812')))  return 'Teclado / Ratón';
    if (serviceUuids.any((u) => u.contains('110b') || u.contains('1108'))) return 'Auriculares';
    if (serviceUuids.any((u) => u.contains('180d') || u.contains('1814'))) return 'Wearable';

    final oui = mac.replaceAll(':', '').toUpperCase();
    final key = oui.length >= 6 ? oui.substring(0, 6) : '';
    const ouiMap = <String, String>{
      'B827EB': 'Raspberry Pi', 'DC5475': 'Raspberry Pi',
      'E45F01': 'Raspberry Pi', '2CCF67': 'Raspberry Pi', 'D83ADD': 'Raspberry Pi',
      'F0B479': 'iPhone / iPad', 'A4C3F0': 'iPhone / iPad',
      '6C4008': 'iPhone / iPad', 'F4F15A': 'iPhone / iPad',
      '8CCE4E': 'Samsung Galaxy', 'B47C9C': 'Samsung Galaxy',
      'F4F5E8': 'Google Pixel',   '3C5AB4': 'Google Pixel',
      '7845C4': 'Microsoft',      '00155D': 'Microsoft',
    };
    if (ouiMap.containsKey(key)) return ouiMap[key]!;

    final shortMac = mac.length >= 5 ? mac.substring(mac.length - 5) : mac;
    return 'Dispositivo (...$shortMac)';
  }

  // ── Escaneo ───────────────────────────────────────────────────────────────────
  Future<List<BleDeviceInfo>> scan({int seconds = 10, bool autoDeepScan = true}) async {
    _log('Iniciando escaneo BLE...');

    if (await fbp.FlutterBluePlus.adapterState.first != fbp.BluetoothAdapterState.on) {
      _log('✗ Bluetooth no activado');
      _setState(BleConnectionState.disconnected);
      return [];
    }
    if (!await Permission.bluetoothScan.isGranted  ||
        !await Permission.bluetoothConnect.isGranted ||
        !await Permission.locationWhenInUse.isGranted) {
      _log('✗ Faltan permisos');
      _setState(BleConnectionState.disconnected);
      return [];
    }

    _liveDevices.clear();
    _setState(BleConnectionState.scanning);

    try {
      for (final d in fbp.FlutterBluePlus.connectedDevices) {
        final n = d.platformName.isNotEmpty ? d.platformName : 'Dispositivo conectado';
        _upsertDevice(BleDeviceInfo._(id: d.remoteId.str, name: n, rssi: 0, device: d));
      }
    } catch (_) {}

    int counter = 0;
    final sub = fbp.FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final mac  = r.device.remoteId.str;
        final name = _resolveDeviceName(
          mac:              mac,
          platformName:     r.device.platformName,
          advName:          r.advertisementData.advName,
          manufacturerData: r.advertisementData.manufacturerData,
          serviceUuids:     r.advertisementData.serviceUuids
              .map((u) => u.str128.toLowerCase()).toList(),
        );
        if (!_liveDevices.containsKey(mac)) {
          counter++;
          _log('  $counter. $name | ${r.rssi} dBm');
        }
        _upsertDevice(BleDeviceInfo._(id: mac, name: name, rssi: r.rssi, device: r.device));
      }
    });

    try {
      await fbp.FlutterBluePlus.startScan(
        timeout: Duration(seconds: seconds),
        continuousUpdates: true,
        androidUsesFineLocation: true,
      );
      await fbp.FlutterBluePlus.isScanning
          .where((s) => !s).first
          .timeout(Duration(seconds: seconds + 2));
    } catch (e) {
      _log('✗ Error escaneo: $e');
    } finally {
      await sub.cancel();
      await fbp.FlutterBluePlus.stopScan();
    }

    _setState(BleConnectionState.disconnected);
    final result = _liveDevices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    _log('✓ ${result.length} dispositivo(s) encontrados');
    return result;
  }

  Future<List<BleDeviceInfo>> deepScan({int seconds = 10}) async => scan(seconds: seconds);

  // ── Conexión ──────────────────────────────────────────────────────────────────
  // Android necesita: escaneo detenido + delay + retry para GATT error 133/bp-code 1
  Future<BleResult> connect(BleDeviceInfo info) async {
    if (isConnected) await disconnect();

    _setState(BleConnectionState.connecting);
    _log('Conectando a "${info.name}"...');
    _setConnectedInfo(info);

    // 1. Parar escaneo — Android no puede escanear y conectar al mismo tiempo
    try { await fbp.FlutterBluePlus.stopScan(); } catch (_) {}
    // 2. Delay crítico post-scan antes de conectar
    await Future.delayed(const Duration(milliseconds: 500));

    return await _connectWithRetry(info, attempt: 1);
  }

  Future<BleResult> _connectWithRetry(BleDeviceInfo info, {required int attempt}) async {
    const maxAttempts = 3;
    _log('  Intento $attempt/$maxAttempts...');

    try {
      // flutter_blue_plus 1.32.x: connect() no acepta timeout como parámetro
      await info._device.connect(autoConnect: false)
          .timeout(const Duration(seconds: 15));
      _log('  ✓ Conexión física establecida');

      _connSub = info._device.connectionState.listen((cs) {
        if (cs == fbp.BluetoothConnectionState.disconnected) {
          _txChar = null; _device = null;
          _setConnectedInfo(null);
          _setState(BleConnectionState.disconnected);
          _log('Dispositivo desconectado');
        }
      });

      _device = info._device;

      // Delay para estabilizar el stack BLE antes de descubrir servicios
      await Future.delayed(const Duration(milliseconds: 300));

      _log('  Descubriendo servicios GATT...');
      final services = await info._device.discoverServices()
          .timeout(const Duration(seconds: 15));
      _log('  ✓ ${services.length} servicio(s) encontrado(s)');
      for (final s in services) {
        _log('    • ${s.uuid.str128.toLowerCase()}');
      }

      // Nombre real desde Generic Access (0x1800/0x2A00)
      final gattName = await _readGattDeviceName(services);
      if (gattName != null && gattName.isNotEmpty) {
        _log('  ✓ Nombre del dispositivo: "$gattName"');
        _setConnectedInfo(BleDeviceInfo._(
            id: info.id, name: gattName, rssi: info.rssi, device: info._device));
      }

      // Buscar NUS TX (app → Raspberry)
      _txChar = _findNusTx(services) ?? _findAnyWritable(services);

      if (_txChar == null) {
        _log('  ✗ No se encontró característica NUS TX');
        _log('  ¿Está corriendo stemBosque_bt_receiver.py en la Raspberry Pi?');
        await disconnect();
        return const BleResult(
          success: false,
          message: 'No se encontró NUS TX.\n¿Está corriendo el script en la Raspberry Pi?',
        );
      }

      _log('  ✓ NUS TX: ${_txChar!.uuid.str128.substring(0, 8)}...');
      _setState(BleConnectionState.connected);
      _log('✓ Conectado a "${_connectedInfo?.name ?? info.name}"');
      return const BleResult(success: true, message: 'Conexión establecida');

    } catch (e) {
      final msg = e.toString();
      _log('  ✗ Intento $attempt: $msg');

      try { await info._device.disconnect(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));

      // GATT 133 / bp-code 1 / timeout → son errores transitorios de Android, hacer retry
      final isTransient = msg.contains('133') ||
          msg.contains('GATT')     ||
          msg.contains('bp-code')  ||
          msg.contains('timeout')  ||
          msg.contains('Timed out');

      if (isTransient && attempt < maxAttempts) {
        _log('  Reintentando en 1s...');
        await Future.delayed(const Duration(seconds: 1));
        return _connectWithRetry(info, attempt: attempt + 1);
      }

      _setState(BleConnectionState.error);
      if (isTransient) {
        _log('✗ No se pudo conectar tras $maxAttempts intentos');
        _log('  Verifica: Raspberry encendida + script BLE corriendo');
        return BleResult(
          success: false,
          message: 'No se pudo conectar tras $maxAttempts intentos.\n'
              'Verifica que la Raspberry Pi está encendida y el script BLE activo.',
        );
      }
      return BleResult(success: false, message: 'Error: $e');
    }
  }

  // ── Nombre GATT (0x1800 → 0x2A00) ────────────────────────────────────────────
  Future<String?> _readGattDeviceName(List<fbp.BluetoothService> services) async {
    try {
      for (final s in services) {
        if (!s.uuid.str128.toLowerCase().contains('1800')) continue;
        for (final c in s.characteristics) {
          if (!c.uuid.str128.toLowerCase().contains('2a00')) continue;
          if (!c.properties.read) continue;
          final value = await c.read();
          if (value.isNotEmpty) return String.fromCharCodes(value).trim();
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Buscar NUS TX — comparación robusta ───────────────────────────────────────
  fbp.BluetoothCharacteristic? _findNusTx(List<fbp.BluetoothService> services) {
    // Comparar solo la parte significativa del UUID (sin guiones, minúsculas)
    final targetSvc  = _kNusServiceUuid.replaceAll('-', '').toLowerCase();
    final targetChar = _kNusTxCharUuid.replaceAll('-', '').toLowerCase();

    for (final s in services) {
      final sUuid = s.uuid.str128.replaceAll('-', '').toLowerCase();
      if (!sUuid.contains(targetSvc.substring(0, 8))) continue;
      for (final c in s.characteristics) {
        final cUuid = c.uuid.str128.replaceAll('-', '').toLowerCase();
        if (cUuid.contains(targetChar.substring(0, 8))) return c;
      }
    }
    return null;
  }

  fbp.BluetoothCharacteristic? _findAnyWritable(List<fbp.BluetoothService> services) {
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) return c;
      }
    }
    return null;
  }

  // ── Desconexión ───────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    try {
      await _connSub?.cancel();
      _connSub = null;
      await _device?.disconnect();
    } catch (_) {}
    _txChar = null; _device = null;
    _setConnectedInfo(null);
    _setState(BleConnectionState.disconnected);
    _log('Desconectado');
  }

  // ── Envío de archivo ──────────────────────────────────────────────────────────
  Future<BleResult> sendProgram(String code, String fileName) async {
    if (!isConnected) {
      _log('✗ No conectado — conecta primero a la Raspberry');
      return const BleResult(success: false, message: 'No hay conexión BLE activa');
    }
    if (_txChar == null) {
      _log('✗ Sin característica TX');
      return const BleResult(success: false, message: 'Sin característica TX');
    }

    _setState(BleConnectionState.transferring);
    _log('► Enviando "$fileName"...');

    try {
      final contentBytes = utf8.encode(code);
      final header = 'STB_START:$fileName:${contentBytes.length}\n';
      final footer = '\nSTB_END\n';

      // Negociar MTU para chunks más grandes
      final mtu      = (_device!.mtuNow - 3).clamp(20, 512);
      final withResp = _txChar!.properties.write;
      _log('  MTU: $mtu | withResponse: $withResp | tamaño: ${contentBytes.length}B');

      Future<void> writeChunk(Uint8List data) async {
        await _txChar!.write(data, withoutResponse: !withResp);
        await Future.delayed(const Duration(milliseconds: 20));
      }

      _log('  Enviando cabecera...');
      await writeChunk(Uint8List.fromList(utf8.encode(header)));

      _log('  Enviando contenido en chunks de $mtu bytes...');
      int sent = 0;
      for (int i = 0; i < contentBytes.length; i += mtu) {
        final end = (i + mtu).clamp(0, contentBytes.length);
        await writeChunk(Uint8List.fromList(contentBytes.sublist(i, end)));
        sent += end - i;
      }
      _log('  $sent/${contentBytes.length} bytes enviados');

      _log('  Enviando fin...');
      await writeChunk(Uint8List.fromList(utf8.encode(footer)));

      _setState(BleConnectionState.connected);
      _log('✓ "$fileName" enviado correctamente');
      return const BleResult(success: true, message: 'Archivo enviado');
    } catch (e) {
      _setState(BleConnectionState.error);
      _log('✗ Error al enviar: $e');
      return BleResult(success: false, message: 'Error al enviar: $e');
    }
  }

  void dispose() {
    _adapterSub?.cancel();
    disconnect();
    _stateCtrl.close();
    _logCtrl.close();
    _adapterCtrl.close();
    _devicesCtrl.close();
    _connectedDevCtrl.close();
  }
}
