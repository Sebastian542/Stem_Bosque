import 'package:flutter/material.dart';
import 'ui/screens/ide_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/permission_request_screen.dart';

void main() {
  runApp(const StemBosqueApp());
}

/// Aplicación principal de StemBosque
class StemBosqueApp extends StatelessWidget {
  const StemBosqueApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PermissionRequestScreen(
      child: MaterialApp(
        title: 'StemBosque - DSL para Robótica',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const IDEScreen(),
      ),
    );
  }
}

