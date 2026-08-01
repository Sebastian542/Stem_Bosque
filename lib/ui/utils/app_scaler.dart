import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Escala globalmente toda la interfaz para que se ajuste de forma
/// proporcional a cualquier dispositivo.
///
/// En teléfonos con pantallas de alta densidad, los elementos con tamaño
/// fijo (dp) se ven "grandes". Este widget redibuja la app en un lienzo
/// lógico más amplio y luego lo reduce para caber en la pantalla real,
/// logrando que todo (texto, botones, barras) se vea más compacto.
class AppScaler extends StatelessWidget {
  const AppScaler({super.key, required this.child});

  final Widget child;

  /// Ancho lógico "de diseño" al que apuntamos en teléfono.
  /// Si la pantalla real es más angosta, se reduce la escala.
  static const double _designWidth = 520;

  double _scaleFor(MediaQueryData mq) {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (!isMobile) return 1.0;

    final shortest = mq.size.shortestSide;
    if (shortest <= 0) return 1.0;

    // Escala para que el lado corto "equivalga" a _designWidth.
    // Limitada para no exagerar en tablets o pantallas ya anchas.
    final scale = shortest / _designWidth;
    return scale.clamp(0.78, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = _scaleFor(mq);

    if (scale >= 0.999) return child;

    final Size scaledSize = mq.size / scale;

    return MediaQuery(
      data: mq.copyWith(
        size: scaledSize,
        padding: mq.padding / scale,
        viewPadding: mq.viewPadding / scale,
        viewInsets: mq.viewInsets / scale,
        systemGestureInsets: mq.systemGestureInsets / scale,
      ),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: scaledSize.width,
          height: scaledSize.height,
          child: child,
        ),
      ),
    );
  }
}
