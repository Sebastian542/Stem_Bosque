import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Ajusta la escala de texto y la densidad en viewports muy pequeños
/// (celular angosto, ventana de escritorio o pestaña web redimensionada)
/// sin distorsionar el layout.
class AppScaler extends StatelessWidget {
  const AppScaler({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final shortest = mq.size.shortestSide;
    final current = mq.textScaler.scale(1.0);

    double factor = 1.0;
    if (shortest > 0 && shortest < 340) {
      factor = 0.88;
    } else if (shortest > 0 && shortest < 380) {
      factor = 0.94;
    }

    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear((current * factor).clamp(0.85, 1.35)),
      ),
      child: child,
    );
  }
}

/// Permite scroll con mouse, trackpad y táctil en todas las plataformas.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
