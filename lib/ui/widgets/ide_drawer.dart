import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/remote_control_screen.dart';
import 'help_dialog.dart';

class IDEDrawer extends StatelessWidget {
  final bool hasUnsavedChanges;
  final bool isRunning;
  final bool bluetoothEnabled;
  //final bool showBluetoothPanel;
  final String? currentFilePath;

  final VoidCallback onOpenFile;
  final VoidCallback onOpenCloud;
  final VoidCallback onSaveFile;
  final VoidCallback onClearCode;
  final VoidCallback onShareFile;
  final VoidCallback onToggleBluetooth;
  final VoidCallback onOpenBlockMode;

  const IDEDrawer({
    super.key,
    required this.hasUnsavedChanges,
    required this.isRunning,
    required this.bluetoothEnabled,
    //required this.showBluetoothPanel,
    required this.currentFilePath,
    required this.onOpenFile,
    required this.onOpenCloud,
    required this.onSaveFile,
    required this.onClearCode,
    required this.onShareFile,
    required this.onToggleBluetooth,
    required this.onOpenBlockMode,
  });

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
                  icon: Icons.cloud_download_rounded,
                  title: 'Abrir desde la Nube',
                  subtitle: 'Sincronizar proyectos guardados',
                  color: AppTheme.purple,
                  onTap: onOpenCloud,
                ),
                _buildItem(
                  context,
                  icon: Icons.folder_open,
                  title: 'Abrir archivo local',
                  subtitle: 'Cargar código desde el dispositivo',
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
                    value: bluetoothEnabled,
                    onChanged: (_) => onToggleBluetooth(),
                    activeThumbColor: AppTheme.green,
                  ),
                ),
                const Divider(color: AppTheme.currentLine, height: 1),
                _buildItem(
                  context,
                  icon: Icons.help_outline_rounded,
                  title: 'Guía de Lenguaje',
                  subtitle: '¿Qué es kw, cmd, trig...?',
                  color: AppTheme.yellow,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const HelpDialog(),
                    );
                  },
                ),
                _buildItem(
                  context,
                  icon: Icons.grid_view_rounded,
                  title: 'Modo Bloque',
                  subtitle: 'Añadir elementos a la simulación',
                  color: AppTheme.green,
                  onTap: onOpenBlockMode,
                ),
                const Divider(color: AppTheme.currentLine, height: 1),
                StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    final bool isLoggedIn = snapshot.hasData;
                    if (!isLoggedIn) {
                      return Column(
                        children: [
                          _buildItem(
                            context,
                            icon: Icons.login_rounded,
                            title: 'Iniciar Sesión',
                            subtitle: 'Sincroniza tus programas en la nube',
                            color: AppTheme.purple,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                          ),
                          _buildItem(
                            context,
                            icon: Icons.gamepad_rounded,
                            title: 'Control Remoto',
                            subtitle: 'Controla el robot en tiempo real',
                            color: AppTheme.cyan,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RemoteControlScreen()),
                              );
                            },
                          ),
                        ],
                      );
                    }

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: AuthService().getCurrentUserProfile(),
                      builder: (context, profileSnapshot) {
                        final profile = profileSnapshot.data;
                        final isAdmin = profile?['role'] == 'admin';
                        final roleName = profile?['role'] ?? 'Cargando...';

                        return Column(
                          children: [
                            _buildItem(
                              context,
                              icon: Icons.gamepad_rounded,
                              title: 'Control Remoto',
                              subtitle: 'Controla el robot en tiempo real',
                              color: AppTheme.cyan,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RemoteControlScreen()),
                                );
                              },
                            ),
                            if (isAdmin)
                              _buildItem(
                                context,
                                icon: Icons.admin_panel_settings_rounded,
                                title: 'Panel de Usuarios',
                                subtitle: 'Administrar permisos y roles',
                                color: AppTheme.yellow,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                                  );
                                },
                              ),
                            _buildItem(
                              context,
                              icon: Icons.logout_rounded,
                              title: 'Cerrar Sesión',
                              subtitle: 'Cuenta: ${snapshot.data?.email}\nRol: $roleName',
                              color: AppTheme.red,
                              onTap: () async {
                                await AuthService().signOut();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
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
      decoration: const BoxDecoration(
        color: AppTheme.currentLine,
        border: Border(bottom: BorderSide(color: AppTheme.comment, width: 1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.code, size: 40, color: AppTheme.cyan),
          SizedBox(height: 12),
          Text('StemBosque IDE',
              style: TextStyle(
                color: AppTheme.foreground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          SizedBox(height: 4),
          Text('Opciones del editor',
              style: TextStyle(color: AppTheme.comment, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
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
                style: const TextStyle(color: AppTheme.comment, fontSize: 12),
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
          const Text('Versión 1.1.0',
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
          color: color.withValues(alpha: 0.1),
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
          style: const TextStyle(color: AppTheme.comment, fontSize: 12)),
      trailing: trailing,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
