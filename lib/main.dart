import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'ui/screens/ide_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/permission_request_screen.dart';

void main() {
  runApp(const StemBosqueApp());
}

/// Aplicación principal de StemBosque
class StemBosqueApp extends StatelessWidget {
  const StemBosqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos el widget base de la aplicación
    final MaterialApp app = MaterialApp(
      title: 'StemBosque - DSL para Robótica',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const IDEScreen(),
    );

    // Si es Web o Desktop, no mostramos la pantalla de permisos de Android
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return app;
    }

    // En Android/iOS, mantenemos el flujo de permisos
    return PermissionRequestScreen(
      child: app,
    );
  }
}
