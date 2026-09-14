import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Clases de ventana (Material 3) según el **ancho real** del viewport.
/// Sirven igual en celular, tablet, escritorio y web redimensionable.
enum ScreenSize { compact, medium, expanded, large }

class Responsive {
  Responsive(this.context);

  final BuildContext context;

  Size get size => MediaQuery.sizeOf(context);
  double get width => size.width;
  double get height => size.height;
  double get shortestSide => size.shortestSide;
  double get longestSide => size.longestSide;
  Orientation get orientation => MediaQuery.orientationOf(context);
  EdgeInsets get viewPadding => MediaQuery.paddingOf(context);
  bool get isLandscape => orientation == Orientation.landscape;

  bool get isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Ancho de teléfono o ventana estrecha (< 600 dp).
  bool get isCompact => width < 600;

  /// Tablet / landscape de teléfono / ventana mediana.
  bool get isMedium => width >= 600 && width < 840;

  /// Escritorio o tablet ancha.
  bool get isExpanded => width >= 840 && width < 1200;

  bool get isLarge => width >= 1200;

  /// Alias de layout estrecho (no depende de la plataforma).
  bool get isPhone => isCompact;

  bool get isTablet => isMedium || (isMobilePlatform && isExpanded);

  /// Teléfono en horizontal: alto bajo, ancho grande.
  bool get isLandscapePhone => isLandscape && height < 500;

  ScreenSize get screenSize {
    if (isLarge) return ScreenSize.large;
    if (isExpanded) return ScreenSize.expanded;
    if (isMedium) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  /// Panel Bluetooth al costado solo cuando hay espacio real.
  bool get useSidePanelLayout => width >= 960 && !isLandscapePhone;

  /// Listas/tarjetas en dos columnas.
  bool get useTwoPane => width >= 720;

  bool get denseControls => isCompact || isLandscapePhone;

  double scale(double base) {
    final factor = (shortestSide / 400).clamp(0.82, 1.25);
    return base * factor;
  }

  double get horizontalPadding {
    if (isCompact) return 12;
    if (isMedium) return 20;
    if (isExpanded) return 28;
    return 36;
  }

  double get verticalPadding {
    if (isCompact || isLandscapePhone) return 8;
    if (isMedium) return 14;
    return 20;
  }

  double get toolbarHeight {
    if (isLandscapePhone) return 44;
    if (isCompact) return 50;
    if (isMedium) return 58;
    return 66;
  }

  double get panelHeight {
    if (isLandscapePhone) return math.max(160, height * 0.55);
    if (isCompact) return (height * 0.38).clamp(200, 320);
    if (isLandscape) return height * 0.45;
    return (height * 0.34).clamp(220, 400);
  }

  double get sidePanelWidth => (width * 0.30).clamp(280, 400);

  double get dialogListHeight => (height * 0.50).clamp(220, 560);

  double get maxFormWidth {
    if (isLarge) return 520;
    if (isExpanded) return 480;
    return 420;
  }

  /// Ancho máximo de contenido (listas, paneles) en pantallas grandes.
  double get contentMaxWidth {
    if (isLarge) return 1080;
    if (isExpanded) return 880;
    if (isMedium) return width;
    return width;
  }

  double get codeFontSize {
    if (isCompact) return 12;
    if (isMedium) return 13.5;
    return 15;
  }

  double get gutterWidth => isCompact ? 28 : isMedium ? 36 : 44;

  double get vampiritoScale {
    if (isLandscapePhone) return 0.45;
    if (isCompact) return 0.55;
    if (isMedium) return 0.8;
    return 1.0;
  }

  double get controlButtonSize {
    final raw = math.min(width, height) * 0.18;
    return raw.clamp(56, 108);
  }

  double get iconSize => denseControls ? 18 : 24;

  double get dialogMaxWidth {
    if (isCompact) return width * 0.94;
    if (width > 720) return 560;
    return width * 0.90;
  }

  double get drawerWidth => math.min(320, width * 0.86);

  EdgeInsets get dialogInsets => EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 24,
        vertical: isCompact ? 16 : 24,
      );

  static Responsive of(BuildContext context) => Responsive(context);
}

extension ResponsiveContext on BuildContext {
  Responsive get responsive => Responsive.of(this);
}

/// Centra y limita el ancho (login, formularios, permisos).
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: r.horizontalPadding,
                vertical: r.verticalPadding,
              ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - r.verticalPadding * 2),
              maxWidth: maxWidth ?? r.maxFormWidth,
            ),
            child: Align(
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Página con padding y ancho máximo para listas/paneles.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = math.min(r.contentMaxWidth, constraints.maxWidth);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxW,
              height: constraints.maxHeight,
              child: Padding(
                padding: padding ??
                    EdgeInsets.symmetric(
                      horizontal: r.horizontalPadding,
                      vertical: r.verticalPadding,
                    ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
