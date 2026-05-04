import 'package:flutter/material.dart';
import '../../bluetooth/bluetooth_manager.dart';
import '../theme/app_theme.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  final _bt = BluetoothManager.instance;
  bool get _isConnected => _bt.connectedDevice != null;

  void _sendCommand(String cmd) {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conecta el Bluetooth para controlar el robot')),
      );
      return;
    }
    _bt.sendInstantCommand(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Remoto'),
        backgroundColor: AppTheme.background,
      ),
      body: Column(
        children: [
          // Estado de conexión
          Container(
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Text(
                  _isConnected 
                    ? 'Conectado a: ${_bt.connectedDevice!.displayName}' 
                    : 'Robot no conectado',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // D-PAD (Controles)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ControlBtn(
                  icon: Icons.arrow_upward, 
                  label: 'AVANZAR', 
                  onTap: () => _sendCommand('AVANZAR'),
                  color: AppTheme.purple,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlBtn(
                      icon: Icons.arrow_back, 
                      label: 'IZQUIERDA', 
                      onTap: () => _sendCommand('GIRAR IZQUIERDA'),
                      color: AppTheme.orange,
                    ),
                    const SizedBox(width: 20),
                    _ControlBtn(
                      icon: Icons.stop_circle, 
                      label: 'PARAR', 
                      onTap: () => _sendCommand('PARAR'),
                      color: Colors.red,
                    ),
                    const SizedBox(width: 20),
                    _ControlBtn(
                      icon: Icons.arrow_forward, 
                      label: 'DERECHA', 
                      onTap: () => _sendCommand('GIRAR DERECHA'),
                      color: AppTheme.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _ControlBtn(
                  icon: Icons.arrow_downward, 
                  label: 'RETROCEDER', 
                  onTap: () => _sendCommand('RETROCEDER'),
                  color: AppTheme.purple,
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Toca las flechas para enviar comandos instantáneos al robot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
