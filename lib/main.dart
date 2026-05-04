import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'ui/screens/ide_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/permission_request_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Error inicializando Firebase: $e");
  }

  runApp(const StemBosqueApp());
}

class StemBosqueApp extends StatelessWidget {
  const StemBosqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    final MaterialApp app = MaterialApp(
      title: 'StemBosque - DSL para Robótica',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const IDEScreen(),
    );

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return app;
    }

    return PermissionRequestScreen(
      child: app,
    );
  }
}
