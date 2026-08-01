import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
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
    super.key,
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
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final panelHeight = r.useSidePanelLayout ? null : r.panelHeight;

    return Container(
      height: panelHeight,
      width: r.useSidePanelLayout ? double.infinity : null,
      decoration: BoxDecoration(
        color: AppTheme.background.withAlpha(245),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        border: const Border(
          bottom: BorderSide(color: AppTheme.purple, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: Column(
          children: [
            _buildHeader(context),
            if (connectedDevice != null) _buildConnectedBanner(),
            Expanded(child: _buildDeviceList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.currentLine.withAlpha(150),
      child: Row(
        children: [
          Icon(
            bluetoothEnabled ? Icons.bluetooth_audio_rounded : Icons.bluetooth_disabled_rounded,
            color: bluetoothEnabled ? AppTheme.cyan : AppTheme.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            r.isPhone ? 'Bluetooth' : 'Panel de Control',
            style: TextStyle(
              color: bluetoothEnabled ? AppTheme.foreground : AppTheme.comment,
              fontWeight: FontWeight.w900,
              fontSize: r.isPhone ? 14 : 18,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          
          if (bluetoothEnabled) 
            _buildActionChip(
              onPressed: isScanning ? onStopScan : onStartScan,
              label: isScanning ? 'DETENER' : 'BUSCAR',
              color: isScanning ? AppTheme.orange : AppTheme.purple,
              icon: isScanning ? Icons.stop_circle : Icons.radar,
            ),
            
          const SizedBox(width: 8),
          
          IconButton(
            onPressed: onToggle,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.background,
              hoverColor: AppTheme.red.withAlpha(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({required VoidCallback onPressed, required String label, required Color color, required IconData icon}) {
    return ActionChip(
      onPressed: onPressed,
      avatar: Icon(icon, size: 16, color: AppTheme.background),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      backgroundColor: color,
      labelStyle: const TextStyle(color: AppTheme.background),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildConnectedBanner() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.green.withAlpha(40), AppTheme.green.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.green.withAlpha(100), width: 1.5),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppTheme.green,
            child: Icon(Icons.check_rounded, color: AppTheme.background),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ROBOT CONECTADO', style: TextStyle(color: AppTheme.green, fontWeight: FontWeight.w900, fontSize: 10)),
                Text(connectedDevice!.displayName, style: const TextStyle(color: AppTheme.foreground, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onDisconnect,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.red,
              side: const BorderSide(color: AppTheme.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('DESCONECTAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context) {
    if (!bluetoothEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled_rounded, size: 60, color: AppTheme.red.withAlpha(100)),
            const SizedBox(height: 16),
            const Text('Bluetooth Desactivado', style: TextStyle(color: AppTheme.comment, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onToggleBluetooth,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green),
              child: const Text('ACTIVAR AHORA'),
            ),
          ],
        ),
      );
    }

    if (isScanning && devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.cyan),
            ),
            SizedBox(height: 20),
            Text('BUSCANDO DISPOSITIVOS...', style: TextStyle(color: AppTheme.cyan, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final isConnected = connectedDevice?.address == device.address;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isConnected ? AppTheme.green.withAlpha(20) : AppTheme.currentLine.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isConnected ? AppTheme.green : AppTheme.comment.withAlpha(50),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(
              device.type == BluetoothDeviceType.ble ? Icons.bolt_rounded : Icons.settings_input_antenna_rounded,
              color: isConnected ? AppTheme.green : AppTheme.cyan,
            ),
            title: Text(device.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(device.address, style: const TextStyle(color: AppTheme.comment, fontSize: 10)),
            trailing: isConnected 
              ? Icon(Icons.check_circle_rounded, color: AppTheme.green)
              : ElevatedButton(
                  onPressed: isConnecting ? null : () => onConnect(device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.background,
                    foregroundColor: AppTheme.purple,
                    side: const BorderSide(color: AppTheme.purple),
                    elevation: 0,
                  ),
                  child: Text(isConnecting ? '...' : 'UNIR'),
                ),
          ),
        );
      },
    );
  }
}
