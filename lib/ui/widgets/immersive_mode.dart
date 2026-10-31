import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla completa "inmersiva": esconde la barra de navegación del sistema
/// (los botones de volver, inicio y apps recientes) y la barra de estado.
///
/// Si la persona desliza desde el borde, el menú del sistema aparece un momento
/// por encima de la app y se vuelve a esconder solo (modo "immersive sticky").
/// Solo se aplica en Android e iOS.
class ImmersiveMode extends StatefulWidget {
  final Widget child;
  const ImmersiveMode({super.key, required this.child});

  @override
  State<ImmersiveMode> createState() => _ImmersiveModeState();
}

class _ImmersiveModeState extends State<ImmersiveMode>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _tecladoAbierto = false;

  bool get _aplica =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ocultarBarras();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver a la app (desde otra app o desde el menú) se esconden de nuevo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ocultarBarras();
  }

  /// Algunos teléfonos vuelven a mostrar la barra cuando se cierra el teclado.
  /// Solo se reacciona a eso (y no a cualquier cambio de pantalla): si no, la
  /// barra que la persona acaba de deslizar desaparecería al instante.
  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final abierto = views.first.viewInsets.bottom > 0;
    if (_tecladoAbierto && !abierto) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 300), _ocultarBarras);
    }
    _tecladoAbierto = abierto;
  }

  void _ocultarBarras() {
    if (!_aplica) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
