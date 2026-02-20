import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../bluetooth/bluetooth_manager.dart';

class BluetoothPanel extends StatelessWidget {
  final bool bluetoothEnabled;
  final bool isScanning;
  final bool isConnecting;
  final List<UnifiedBluetoothDevice> devices;
  final UnifiedBluetoothDevice? connectedDevice;

  final VoidCallback onToggle;
  final VoidCallback onToggleBluetooth;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;
  final VoidCallback onOpenSettings;
  final VoidCallback onDisconnect;
  final void Function(UnifiedBluetoothDevice) onConnect;

  const BluetoothPanel({
    Key? key,
    required this.bluetoothEnabled,
    required this.isScanning,
    required this.isConnecting,
    required this.devices,
    required this.connectedDevice,
    required this.onToggle,
    required this.onToggleBluetooth,
    required this.onStartScan,
    required this.onStopScan,
    required this.onOpenSettings,
    required this.onDisconnect,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
            bottom: BorderSide(color: AppTheme.currentLine, width: 2)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (connectedDevice != null) _buildConnectedBanner(),
          Expanded(child: _buildDeviceList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                bluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                color: bluetoothEnabled ? AppTheme.cyan : AppTheme.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                bluetoothEnabled ? 'Bluetooth' : 'Bluetooth Desactivado',
                style: TextStyle(
                  color: bluetoothEnabled ? AppTheme.cyan : AppTheme.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onToggleBluetooth,
                icon: Icon(
                  bluetoothEnabled
                      ? Icons.bluetooth_disabled
                      : Icons.bluetooth,
                  size: 18,
                ),
                label: Text(bluetoothEnabled ? 'Apagar' : 'Encender'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  bluetoothEnabled ? AppTheme.red : AppTheme.green,
                  foregroundColor: AppTheme.background,
                ),
              ),
              const SizedBox(width: 8),
              if (bluetoothEnabled)
                ElevatedButton.icon(
                  onPressed: isScanning ? onStopScan : onStartScan,
                  icon: Icon(isScanning ? Icons.stop : Icons.search, size: 18),
                  label: Text(isScanning ? 'Detener' : 'Escanear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isScanning ? AppTheme.orange : AppTheme.purple,
                    foregroundColor: AppTheme.background,
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onToggle,
                icon: const Icon(Icons.close),
                color: AppTheme.comment,
              ),
            ],
          ),
          if (bluetoothEnabled && devices.isEmpty && !isScanning)
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
                  const Icon(Icons.info_outline,
                      color: AppTheme.orange, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '¿No ves tu dispositivo? Vincúlalo primero desde la configuración',
                      style:
                      TextStyle(color: AppTheme.foreground, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_bluetooth, size: 16),
                    label: const Text('Vincular'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cyan,
                      foregroundColor: AppTheme.background,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectedBanner() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.currentLine,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.green, width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_connected,
              color: AppTheme.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CONECTADO',
                    style: TextStyle(
                        color: AppTheme.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text(
                  connectedDevice!.displayName,
                  style: const TextStyle(
                      color: AppTheme.foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDisconnect,
            icon: const Icon(Icons.close),
            color: AppTheme.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (!bluetoothEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled,
                size: 48, color: AppTheme.comment),
            const SizedBox(height: 12),
            Text('Active el Bluetooth',
                style: TextStyle(color: AppTheme.comment)),
          ],
        ),
      );
    }

    if (isScanning && devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.cyan),
            SizedBox(height: 12),
            Text('Buscando...',
                style: TextStyle(color: AppTheme.foreground)),
          ],
        ),
      );
    }

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.devices, size: 48, color: AppTheme.comment),
            const SizedBox(height: 12),
            Text('No se encontraron dispositivos',
                style: TextStyle(color: AppTheme.comment)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device      = devices[index];
        final isConnected = connectedDevice?.address == device.address;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AppTheme.currentLine,
            borderRadius: BorderRadius.circular(6),
            border: isConnected
                ? Border.all(color: AppTheme.green, width: 2)
                : null,
          ),
          child: ListTile(
            dense: true,
            leading: Icon(
              device.type == BluetoothDeviceType.ble
                  ? Icons.bluetooth
                  : Icons.bluetooth_connected,
              color: isConnected ? AppTheme.green : AppTheme.cyan,
              size: 24,
            ),
            title: Text(device.displayName,
                style: const TextStyle(
                    color: AppTheme.foreground,
                    fontWeight: FontWeight.bold)),
            subtitle: Text(device.address,
                style: const TextStyle(
                    color: AppTheme.comment, fontSize: 11)),
            trailing: isConnected
                ? const Chip(
              label: Text('Conectado',
                  style: TextStyle(fontSize: 10)),
              backgroundColor: AppTheme.green,
            )
                : ElevatedButton(
              onPressed:
              isConnecting ? null : () => onConnect(device),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: AppTheme.foreground,
              ),
              child: Text(isConnecting ? 'Conectando...' : 'Conectar'),
            ),
          ),
        );
      },
    );
  }
}