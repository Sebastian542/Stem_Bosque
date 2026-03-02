import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class IDEDrawer extends StatelessWidget {
  final bool hasUnsavedChanges;
  final bool isRunning;
  final bool bluetoothEnabled;
  //final bool showBluetoothPanel;
  final String? currentFilePath;

  final VoidCallback onOpenFile;
  final VoidCallback onSaveFile;
  final VoidCallback onClearCode;
  final VoidCallback onShareFile;
  final VoidCallback onToggleBluetooth;

  const IDEDrawer({
    Key? key,
    required this.hasUnsavedChanges,
    required this.isRunning,
    required this.bluetoothEnabled,
    //required this.showBluetoothPanel,
    required this.currentFilePath,
    required this.onOpenFile,
    required this.onSaveFile,
    required this.onClearCode,
    required this.onShareFile,
    required this.onToggleBluetooth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.background,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildItem(
                  context,
                  icon: Icons.folder_open,
                  title: 'Abrir archivo',
                  subtitle: 'Cargar código desde archivo',
                  color: AppTheme.cyan,
                  onTap: onOpenFile,
                ),
                _buildItem(
                  context,
                  icon: Icons.save,
                  title: 'Guardar archivo',
                  subtitle: hasUnsavedChanges
                      ? 'Hay cambios sin guardar'
                      : 'Código guardado',
                  color: hasUnsavedChanges ? AppTheme.orange : AppTheme.purple,
                  onTap: onSaveFile,
                ),
                _buildItem(
                  context,
                  icon: Icons.clear_all,
                  title: 'Limpiar código',
                  subtitle: 'Borrar todo el editor',
                  color: AppTheme.orange,
                  onTap: onClearCode,
                ),
                _buildItem(
                  context,
                  icon: Icons.share,
                  title: 'Compartir archivo',
                  subtitle: 'Enviar por Bluetooth u otra app',
                  color: AppTheme.cyan,
                  onTap: onShareFile,
                ),
                const Divider(color: AppTheme.currentLine, height: 1),
                // ANTES: el item tenía un Switch que mostraba/ocultaba el panel
                // y el valor era showBluetoothPanel
                // _buildItem(
                //   context,
                //   icon: bluetoothEnabled
                //       ? Icons.bluetooth
                //       : Icons.bluetooth_disabled,
                //   title: 'Bluetooth',
                //   subtitle: bluetoothEnabled ? 'Disponible' : 'Desactivado',
                //   color: bluetoothEnabled ? AppTheme.green : AppTheme.red,
                //   onTap: onToggleBluetooth,
                //   trailing: Switch(
                //     value: showBluetoothPanel,
                //     onChanged: (_) => onToggleBluetooth(),
                //     activeColor: AppTheme.green,
                //   ),
                // ),
                // AHORA: el Switch refleja si el bluetooth del celular
                // está encendido o apagado, y al tocarlo lo enciende/apaga
                _buildItem(
                  context,
                  icon: bluetoothEnabled
                      ? Icons.bluetooth
                      : Icons.bluetooth_disabled,
                  title: 'Bluetooth',
                  subtitle: bluetoothEnabled
                      ? 'Encendido — toca para apagar'
                      : 'Apagado — toca para encender',
                  color: bluetoothEnabled ? AppTheme.green : AppTheme.comment,
                  onTap: onToggleBluetooth,
                  trailing: Switch(
                    value: bluetoothEnabled,  // ANTES: showBluetoothPanel
                    onChanged: (_) => onToggleBluetooth(),
                    activeColor: AppTheme.green,
                  ),
                ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.currentLine,
        border: Border(bottom: BorderSide(color: AppTheme.comment, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.code, size: 40, color: AppTheme.cyan),
          const SizedBox(height: 12),
          const Text('StemBosque IDE',
              style: TextStyle(
                color: AppTheme.foreground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 4),
          Text('Opciones del editor',
              style: TextStyle(color: AppTheme.comment, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.currentLine, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRunning ? Icons.pending : Icons.check_circle,
                size: 16,
                color: isRunning ? AppTheme.orange : AppTheme.green,
              ),
              const SizedBox(width: 8),
              Text(
                isRunning ? 'Ejecutando...' : 'Listo',
                style: TextStyle(color: AppTheme.comment, fontSize: 12),
              ),
            ],
          ),
          if (currentFilePath != null) ...[
            const SizedBox(height: 8),
            Text(
              '📁 ${currentFilePath!.split('/').last}',
              style: const TextStyle(color: AppTheme.cyan, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          const Text('Versión 1.0.5',
              style: TextStyle(color: AppTheme.comment, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
        Widget? trailing,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title,
          style: const TextStyle(
            color: AppTheme.foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          )),
      subtitle: Text(subtitle,
          style: TextStyle(color: AppTheme.comment, fontSize: 12)),
      trailing: trailing,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}