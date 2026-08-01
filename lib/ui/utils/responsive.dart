import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Breakpoints alineados con Material Design 3.
enum ScreenSize { compact, medium, expanded }

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

  /// Android/iOS nativo (no web embebida en móvil).
  bool get isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Teléfono Android/iOS — siempre layout móvil (pantallas de alta densidad
  /// como el Edge 60 Fusion reportan >1000 dp lógicos).
  bool get isPhone => isMobilePlatform;

  /// Tablet: reservado para futuro; umbral alto para no confundir phones HD.
  bool get isTablet =>
      isMobilePlatform && shortestSide >= 900 && longestSide >= 1200;

  bool get isCompact => isPhone || shortestSide < 600;

  bool get isMedium {
    if (isPhone) return false;
    if (isTablet) return true;
    return shortestSide >= 600 && shortestSide < 840;
  }

  /// Layout expandido: solo escritorio o web en pantalla grande.
  bool get isExpanded {
    if (isMobilePlatform) return false;
    if (kIsWeb) return shortestSide >= 840;
    return isDesktopPlatform && shortestSide >= 600;
  }

  /// Panel lateral solo en escritorio con espacio suficiente.
  bool get useSidePanelLayout => isExpanded && width >= 900;

  ScreenSize get screenSize {
    if (isExpanded) return ScreenSize.expanded;
    if (isMedium) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  double scale(double base) {
    if (isPhone) return base * (shortestSide / 400).clamp(0.75, 1.0);
    if (isCompact) return base * 0.9;
    if (isMedium) return base * 1.05;
    return base * 1.1;
  }

  double get horizontalPadding =>
      isPhone ? 12 : isCompact ? 16 : isMedium ? 24 : 32;

  double get verticalPadding =>
      isPhone ? 8 : isCompact ? 12 : isMedium ? 16 : 20;

  double get toolbarHeight => isPhone ? 46 : isCompact ? 56 : 70;

  double get panelHeight {
    if (isPhone && isLandscape) return height * 0.65;
    if (isPhone) return (height * 0.38).clamp(200, 340);
    if (isLandscape) return height * 0.55;
    return (height * 0.35).clamp(220, 420);
  }

  double get sidePanelWidth => (width * 0.32).clamp(300, 420);

  double get dialogListHeight =>
      (height * 0.45).clamp(240, 520);

  double get maxFormWidth => isExpanded ? 480 : 400;

  double get codeFontSize => isPhone ? 11.5 : isCompact ? 13 : isMedium ? 14 : 15;

  double get gutterWidth => isPhone ? 28 : isCompact ? 36 : 44;

  double get vampiritoScale {
    if (isPhone && isLandscape) return 0.5;
    if (isPhone) return 0.55;
    if (isCompact && isLandscape) return 0.6;
    if (isCompact) return 0.75;
    if (isMedium) return 0.9;
    return 1.0;
  }

  double get controlButtonSize =>
      isPhone ? 52 : isCompact ? 64 : isMedium ? 80 : 96;

  double get iconSize => isPhone ? 18 : isCompact ? 20 : 24;

  /// Escala compacta para botones/íconos de la toolbar en teléfono.
  bool get denseControls => isPhone;

  double get dialogMaxWidth =>
      isPhone ? width * 0.94 : width > 720 ? 560 : width * 0.92;

  static Responsive of(BuildContext context) => Responsive(context);
}

extension ResponsiveContext on BuildContext {
  Responsive get responsive => Responsive.of(this);
}

/// Limita el ancho de contenido en pantallas grandes (login, formularios).
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
    return Center(
      child: SingleChildScrollView(
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: r.horizontalPadding,
              vertical: r.verticalPadding,
            ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? r.maxFormWidth),
          child: child,
        ),
      ),
    );
  }
}
