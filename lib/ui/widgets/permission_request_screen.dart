import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/responsive.dart';

/// Widget que solicita permisos BLE al iniciar la app
class PermissionRequestScreen extends StatefulWidget {
  final Widget child;

  const PermissionRequestScreen({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _permissionsGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // En Web no se manejan permisos de esta forma, saltamos la verificación
    if (kIsWeb) {
      setState(() {
        _permissionsGranted = true;
        _checking = false;
      });
      return;
    }

    // Primero verificar si ya están concedidos
    final granted = await _arePermissionsGranted();

    if (granted) {
      setState(() {
        _permissionsGranted = true;
        _checking = false;
      });
      return;
    }

    // Si no, mostrar el diálogo y solicitar
    setState(() => _checking = false);
  }

  Future<bool> _arePermissionsGranted() async {
    final perms = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    for (final p in perms) {
      final status = await p.status;
      if (!status.isGranted) return false;
    }
    return true;
  }

  Future<void> _requestPermissions() async {
    final perms = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    // Solicitar todos a la vez
    final results = await perms.request();

    // Verificar si todos fueron concedidos
    bool allGranted = true;
    bool anyPermanentlyDenied = false;

    for (final entry in results.entries) {
      if (entry.value.isPermanentlyDenied) {
        anyPermanentlyDenied = true;
        allGranted = false;
      } else if (!entry.value.isGranted) {
        allGranted = false;
      }
    }

    if (anyPermanentlyDenied) {
      // Mostrar diálogo para ir a Ajustes
      _showSettingsDialog();
    } else if (allGranted) {
      setState(() => _permissionsGranted = true);
    } else {
      // Permisos denegados (pero no permanentemente)
      _showDeniedDialog();
    }
  }

  Future<void> _showSettingsDialog() async {
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Permisos necesarios'),
          ],
        ),
        content: const Text(
          'Los permisos de Bluetooth y Ubicación son necesarios para usar StemBosque.\n\n'
              'Por favor, actívalos manualmente en Ajustes → Aplicaciones → StemBosque → Permisos.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Salir'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );

    if (go == true) {
      await openAppSettings();
      // Verificar de nuevo cuando vuelva
      Future.delayed(const Duration(milliseconds: 500), () async {
        final granted = await _arePermissionsGranted();
        if (mounted) {
          setState(() => _permissionsGranted = granted);
        }
      });
    }
  }

  Future<void> _showDeniedDialog() async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permisos denegados'),
        content: const Text(
          'StemBosque necesita permisos de Bluetooth y Ubicación para funcionar.\n\n'
              '¿Deseas intentar de nuevo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Salir'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );

    if (retry == true) {
      _requestPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (!_permissionsGranted) {
      final r = context.responsive;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: ResponsiveCenter(
              maxWidth: 520,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bluetooth_searching,
                    size: r.scale(80),
                    color: Colors.blue,
                  ),
                  SizedBox(height: r.verticalPadding),
                  Text(
                    'Permisos necesarios',
                    style: TextStyle(
                      fontSize: r.isCompact ? 20 : 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: r.verticalPadding * 0.75),
                  Text(
                    'StemBosque necesita acceso a Bluetooth y Ubicación para '
                        'conectarse con la Raspberry Pi.',
                    style: TextStyle(fontSize: r.isCompact ? 14 : 16, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: r.verticalPadding * 2),
                  _buildPermissionItem(
                    Icons.bluetooth,
                    'Bluetooth',
                    'Para buscar y conectar con dispositivos',
                  ),
                  SizedBox(height: r.verticalPadding),
                  _buildPermissionItem(
                    Icons.location_on,
                    'Ubicación',
                    'Requerida por Android para escaneo BLE',
                  ),
                  SizedBox(height: r.verticalPadding * 3),
                  SizedBox(
                    width: double.infinity,
                    height: r.isCompact ? 48 : 50,
                    child: ElevatedButton.icon(
                      onPressed: _requestPermissions,
                      icon: Icon(Icons.check_circle, size: r.iconSize),
                      label: Text(
                        'Conceder permisos',
                        style: TextStyle(
                          fontSize: r.isCompact ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Permisos concedidos, mostrar la app normal
    return widget.child;
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}