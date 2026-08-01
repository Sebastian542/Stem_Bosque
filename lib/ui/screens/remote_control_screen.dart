import 'package:flutter/material.dart';
import '../../bluetooth/bluetooth_manager.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

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
    final r = context.responsive;
    final btnSize = r.controlButtonSize;
    final gap = r.isCompact ? 12.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Remoto'),
        backgroundColor: AppTheme.background,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(r.horizontalPadding * 0.75),
              color: _isConnected
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isConnected
                          ? 'Conectado a: ${_bt.connectedDevice!.displayName}'
                          : 'Robot no conectado',
                      style: TextStyle(
                        color: _isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: r.isCompact ? 13 : 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ControlBtn(
                        icon: Icons.arrow_upward,
                        label: 'AVANZAR',
                        onTap: () => _sendCommand('AVANZAR'),
                        color: AppTheme.purple,
                        size: btnSize,
                        compact: r.isCompact,
                      ),
                      SizedBox(height: gap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ControlBtn(
                            icon: Icons.arrow_back,
                            label: 'IZQUIERDA',
                            onTap: () => _sendCommand('GIRAR IZQUIERDA'),
                            color: AppTheme.orange,
                            size: btnSize,
                            compact: r.isCompact,
                          ),
                          SizedBox(width: gap),
                          _ControlBtn(
                            icon: Icons.stop_circle,
                            label: 'PARAR',
                            onTap: () => _sendCommand('PARAR'),
                            color: Colors.red,
                            size: btnSize,
                            compact: r.isCompact,
                          ),
                          SizedBox(width: gap),
                          _ControlBtn(
                            icon: Icons.arrow_forward,
                            label: 'DERECHA',
                            onTap: () => _sendCommand('GIRAR DERECHA'),
                            color: AppTheme.orange,
                            size: btnSize,
                            compact: r.isCompact,
                          ),
                        ],
                      ),
                      SizedBox(height: gap),
                      _ControlBtn(
                        icon: Icons.arrow_downward,
                        label: 'RETROCEDER',
                        onTap: () => _sendCommand('RETROCEDER'),
                        color: AppTheme.purple,
                        size: btnSize,
                        compact: r.isCompact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(r.horizontalPadding),
              child: Text(
                'Toca las flechas para enviar comandos instantáneos al robot.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: r.isCompact ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final bool compact;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.size,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: size * 0.4),
            SizedBox(height: compact ? 2 : 4),
            if (!compact)
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
