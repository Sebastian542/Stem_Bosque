import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';

/// Pantalla para gestión de Bluetooth
class BluetoothScreen extends StatefulWidget {
  final String? codeToSend; // Código del IDE para enviar
  
  const BluetoothScreen({
    Key? key,
    this.codeToSend,
  }) : super(key: key);

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  // Estado de Bluetooth
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  
  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  /// Inicializar Bluetooth
  Future<void> _initBluetooth() async {
    // Suscribirse al estado del adaptador
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _adapterState = state);
      }
    });

    // Obtener estado actual
    _adapterState = await FlutterBluePlus.adapterState.first;
    
    // Solicitar permisos
    await _requestPermissions();
  }

  /// Solicitar permisos necesarios
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);
    
    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requieren permisos de Bluetooth y ubicación'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  /// Escanear dispositivos Bluetooth
  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    try {
      // Suscribirse a resultados del escaneo
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() => _scanResults = results);
        }
      });

      // Iniciar escaneo por 10 segundos
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      // Esperar a que termine
      await Future.delayed(const Duration(seconds: 10));
      
    } catch (e) {
      _showError('Error al escanear: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  /// Detener escaneo
  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }

  /// Conectar a un dispositivo
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _showInfo('Conectando a ${device.platformName}...');
      
      await device.connect(timeout: const Duration(seconds: 15));
      
      setState(() => _connectedDevice = device);
      
      _showSuccess('Conectado a ${device.platformName}');
      
      // Si hay código para enviar, mostrarlo
      if (widget.codeToSend != null) {
        _showSendCodeDialog();
      }
      
    } catch (e) {
      _showError('Error al conectar: $e');
    }
  }

  /// Desconectar del dispositivo
  Future<void> _disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        setState(() => _connectedDevice = null);
        _showInfo('Desconectado');
      } catch (e) {
        _showError('Error al desconectar: $e');
      }
    }
  }

  /// Mostrar diálogo para enviar código
  void _showSendCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Enviar código', style: TextStyle(color: AppTheme.foreground)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Desea enviar el código actual al dispositivo ${_connectedDevice?.platformName}?',
              style: const TextStyle(color: AppTheme.foreground),
            ),
            const SizedBox(height: 12),
            Text(
              'Tamaño: ${widget.codeToSend?.length ?? 0} caracteres',
              style: const TextStyle(color: AppTheme.comment, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.cyan)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendCode();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
            child: const Text('Enviar', style: TextStyle(color: AppTheme.background)),
          ),
        ],
      ),
    );
  }

  /// Enviar código al dispositivo conectado
  Future<void> _sendCode() async {
    if (_connectedDevice == null || widget.codeToSend == null) return;

    try {
      _showInfo('Enviando código...');
      
      // Descubrir servicios
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      
      // Buscar característica para escribir
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            // Convertir código a bytes
            List<int> bytes = widget.codeToSend!.codeUnits;
            
            // Enviar en chunks de 20 bytes (máximo MTU típico)
            for (int i = 0; i < bytes.length; i += 20) {
              int end = (i + 20 < bytes.length) ? i + 20 : bytes.length;
              List<int> chunk = bytes.sublist(i, end);
              
              await characteristic.write(chunk, withoutResponse: false);
              await Future.delayed(const Duration(milliseconds: 100));
            }
            
            _showSuccess('Código enviado exitosamente');
            return;
          }
        }
      }
      
      _showError('No se encontró característica para escribir');
      
    } catch (e) {
      _showError('Error al enviar código: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexión Bluetooth'),
        actions: [
          if (_connectedDevice != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnect,
              tooltip: 'Desconectar',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildBluetoothStatus(),
          _buildConnectedDevice(),
          Expanded(child: _buildDeviceList()),
        ],
      ),
      floatingActionButton: _adapterState == BluetoothAdapterState.on
          ? FloatingActionButton.extended(
              onPressed: _isScanning ? _stopScan : _startScan,
              backgroundColor: _isScanning ? AppTheme.red : AppTheme.green,
              icon: Icon(_isScanning ? Icons.stop : Icons.search),
              label: Text(_isScanning ? 'Detener' : 'Escanear'),
            )
          : null,
    );
  }

  /// Widget de estado de Bluetooth
  Widget _buildBluetoothStatus() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_adapterState) {
      case BluetoothAdapterState.on:
        statusColor = AppTheme.green;
        statusText = 'Bluetooth activado';
        statusIcon = Icons.bluetooth;
        break;
      case BluetoothAdapterState.off:
        statusColor = AppTheme.red;
        statusText = 'Bluetooth desactivado';
        statusIcon = Icons.bluetooth_disabled;
        break;
      default:
        statusColor = AppTheme.yellow;
        statusText = 'Estado desconocido';
        statusIcon = Icons.bluetooth_searching;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppTheme.currentLine,
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Widget de dispositivo conectado
  Widget _buildConnectedDevice() {
    if (_connectedDevice == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.currentLine,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.green, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_connected, color: AppTheme.green, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conectado',
                  style: TextStyle(color: AppTheme.green, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _connectedDevice!.platformName.isNotEmpty 
                      ? _connectedDevice!.platformName 
                      : 'Dispositivo sin nombre',
                  style: const TextStyle(
                    color: AppTheme.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _connectedDevice!.remoteId.toString(),
                  style: const TextStyle(color: AppTheme.comment, fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.codeToSend != null)
            ElevatedButton.icon(
              onPressed: _sendCode,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Enviar código'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: AppTheme.foreground,
              ),
            ),
        ],
      ),
    );
  }

  /// Widget de lista de dispositivos
  Widget _buildDeviceList() {
    if (_adapterState != BluetoothAdapterState.on) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 64, color: AppTheme.comment),
            const SizedBox(height: 16),
            Text(
              'Active el Bluetooth para escanear dispositivos',
              style: TextStyle(color: AppTheme.comment, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_isScanning && _scanResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.cyan),
            SizedBox(height: 16),
            Text(
              'Buscando dispositivos...',
              style: TextStyle(color: AppTheme.foreground, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_scanResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 64, color: AppTheme.comment),
            const SizedBox(height: 16),
            Text(
              'No se encontraron dispositivos',
              style: TextStyle(color: AppTheme.comment, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Presione el botón de escanear',
              style: TextStyle(color: AppTheme.comment, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _scanResults.length,
      itemBuilder: (context, index) {
        final result = _scanResults[index];
        return _buildDeviceCard(result);
      },
    );
  }

  /// Widget de tarjeta de dispositivo
  Widget _buildDeviceCard(ScanResult result) {
    final device = result.device;
    final isConnected = _connectedDevice?.remoteId == device.remoteId;

    return Card(
      color: isConnected ? AppTheme.currentLine.withOpacity(0.5) : AppTheme.currentLine,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: isConnected ? AppTheme.green : AppTheme.cyan,
          size: 32,
        ),
        title: Text(
          device.platformName.isNotEmpty ? device.platformName : 'Dispositivo sin nombre',
          style: const TextStyle(
            color: AppTheme.foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.remoteId.toString(),
              style: const TextStyle(color: AppTheme.comment, fontSize: 12),
            ),
            Text(
              'RSSI: ${result.rssi} dBm',
              style: TextStyle(
                color: _getRssiColor(result.rssi),
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: isConnected
            ? const Chip(
                label: Text('Conectado', style: TextStyle(fontSize: 11)),
                backgroundColor: AppTheme.green,
                labelStyle: TextStyle(color: AppTheme.background),
              )
            : ElevatedButton(
                onPressed: () => _connectToDevice(device),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.purple,
                  foregroundColor: AppTheme.foreground,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Conectar'),
              ),
      ),
    );
  }

  /// Obtener color según la intensidad de señal
  Color _getRssiColor(int rssi) {
    if (rssi >= -60) return AppTheme.green;
    if (rssi >= -80) return AppTheme.yellow;
    return AppTheme.red;
  }

  // Métodos de utilidad para mostrar mensajes
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.green,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.cyan,
      ),
    );
  }
}
