import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;

enum BluetoothDeviceType { ble, classic }

class UnifiedBluetoothDevice {
  final String name;
  final String address;
  final BluetoothDeviceType type;
  final int? rssi;
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

  String get displayName =>
      name.isNotEmpty ? name : 'Dispositivo (${address.substring(0, 8)}...)';
}