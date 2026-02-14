import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Barra de herramientas con botones de acción
class Toolbar extends StatelessWidget {
  final VoidCallback? onRun;
  final VoidCallback? onClear;
  final VoidCallback? onOpen;
  final VoidCallback? onSave;
  final VoidCallback? onBluetooth;
  final bool isRunning;
  final bool isBluetoothOpen;

  const Toolbar({
    Key? key,
    this.onRun,
    this.onClear,
    this.onOpen,
    this.onSave,
    this.onBluetooth,
    this.isRunning = false,
    this.isBluetoothOpen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1f29),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.currentLine,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          // Botón Ejecutar
          _buildButton(
            context: context,
            label: isRunning ? 'Ejecutando...' : 'Ejecutar',
            icon: isRunning ? Icons.stop : Icons.play_arrow,
            color: AppTheme.green,
            onPressed: isRunning ? null : onRun,
          ),
          
          const SizedBox(width: 10),
          
          // Botón Abrir
          _buildButton(
            context: context,
            label: 'Abrir',
            icon: Icons.folder_open,
            color: AppTheme.cyan,
            onPressed: onOpen,
          ),
          
          const SizedBox(width: 10),
          
          // Botón Guardar
          _buildButton(
            context: context,
            label: 'Guardar',
            icon: Icons.save,
            color: AppTheme.purple,
            onPressed: onSave,
          ),
          
          const SizedBox(width: 10),
          
          // Botón Limpiar
          _buildButton(
            context: context,
            label: 'Limpiar',
            icon: Icons.clear,
            color: AppTheme.red,
            onPressed: onClear,
            textColor: Colors.white,
          ),
          
          const Spacer(),
          
          // Botón Bluetooth
          _buildButton(
            context: context,
            label: isBluetoothOpen ? 'Cerrar BT' : 'Bluetooth',
            icon: isBluetoothOpen ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isBluetoothOpen ? AppTheme.cyan : AppTheme.comment,
            onPressed: onBluetooth,
            textColor: AppTheme.background,
          ),
          
          const SizedBox(width: 16),
          
          // Información de versión
          const Text(
            'StemBosque v0.5',
            style: TextStyle(
              color: AppTheme.comment,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    Color? textColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor ?? AppTheme.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        elevation: 2,
      ),
    );
  }
}
