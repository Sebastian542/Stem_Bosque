import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'help_dialog.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ESTADOS Y EXPRESIONES
// ═══════════════════════════════════════════════════════════════════════════

enum VampiritoState { idle, watching, error, running, success }

enum _Expression { neutral, happy, confused, excited, watching }

// ═══════════════════════════════════════════════════════════════════════════
// CONTENIDO DEL GLOBO
// ═══════════════════════════════════════════════════════════════════════════

class _BubbleContent {
  final String   text;
  final String?  tip;
  final Color    color;
  final IconData icon;
  const _BubbleContent({
    required this.text,
    required this.tip,
    required this.color,
    required this.icon,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET 1 — VampiritoPet (mascota permanente en la UI)
// ═══════════════════════════════════════════════════════════════════════════

class VampiritoPet extends StatefulWidget {
  final VampiritoState state;
  final String?        errorMessage;
  final bool           isTyping;

  const VampiritoPet({
    Key? key,
    required this.state,
    this.errorMessage,
    this.isTyping = false,
  }) : super(key: key);

  @override
  State<VampiritoPet> createState() => _VampiritoPetState();
}

class _VampiritoPetState extends State<VampiritoPet>
    with TickerProviderStateMixin {

  late final AnimationController _floatCtrl;
  late final Animation<double>   _floatY;
  late final AnimationController _shakeCtrl;
  late final AnimationController _jumpCtrl;
  late final AnimationController _bubbleCtrl;
  late final Animation<double>   _bubbleScale;

  _Expression _expr       = _Expression.neutral;
  bool        _showBubble = false;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: 0, end: 7).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _shakeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 550),
    );

    _jumpCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 750),
    );

    _bubbleCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 280),
    );
    _bubbleScale = CurvedAnimation(
      parent: _bubbleCtrl,
      curve:  Curves.easeOutBack,
    );

    _applyState(widget.state, initial: true);
  }

  @override
  void didUpdateWidget(VampiritoPet old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state ||
        old.errorMessage != widget.errorMessage) {
      _applyState(widget.state);
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _shakeCtrl.dispose();
    _jumpCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  // ── Máquina de estados ────────────────────────────────────────────────────

  void _applyState(VampiritoState state, {bool initial = false}) {
    _Expression newExpr;
    bool        bubble;

    switch (state) {
      case VampiritoState.idle:
        newExpr = _Expression.neutral;
        bubble  = false;
        _setFloatSpeed(2000);
        break;

      case VampiritoState.watching:
        newExpr = _Expression.watching;
        bubble  = false;
        _setFloatSpeed(2000);
        break;

      case VampiritoState.error:
        newExpr = _Expression.confused;
        bubble  = widget.errorMessage != null;
        _shakeCtrl.forward(from: 0);
        break;

      case VampiritoState.running:
        newExpr = _Expression.excited;
        bubble  = true;
        _setFloatSpeed(500);
        break;

      case VampiritoState.success:
        newExpr = _Expression.happy;
        bubble  = true;
        _jumpCtrl.forward(from: 0);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && widget.state == VampiritoState.success) {
            _bubbleCtrl.reverse();
            if (mounted) setState(() => _showBubble = false);
          }
        });
        break;
    }

    if (initial) {
      _expr       = newExpr;
      _showBubble = bubble;
    } else {
      setState(() {
        _expr       = newExpr;
        _showBubble = bubble;
      });
    }

    if (bubble) {
      _bubbleCtrl.forward(from: 0);
    } else if (!initial) {
      _bubbleCtrl.reverse();
    }
  }

  void _setFloatSpeed(int ms) {
    if (_floatCtrl.duration?.inMilliseconds != ms) {
      _floatCtrl.stop();
      _floatCtrl.duration = Duration(milliseconds: ms);
      _floatCtrl.repeat(reverse: true);
    }
  }

  // ── Offsets ───────────────────────────────────────────────────────────────

  double get _shakeX =>
      math.sin(_shakeCtrl.value * math.pi * 5) * 9 * (1 - _shakeCtrl.value);

  double _jumpOffset(double jv) {
    if (jv == 0) return 0;
    return jv < 0.45
        ? -38.0 * (jv / 0.45)
        : -38.0 * (1.0 - (jv - 0.45) / 0.55);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity:  widget.isTyping ? 0.15 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Globo de diálogo ───────────────────────────────────────────
          AnimatedSwitcher(
            duration:          const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale:     CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              alignment: Alignment.bottomRight,
              child:     FadeTransition(opacity: anim, child: child),
            ),
            child: _showBubble
                ? Padding(
              key:     ValueKey('${widget.state}_${widget.errorMessage}'),
              padding: const EdgeInsets.only(bottom: 8),
              child:   _buildBubble(),
            )
                : const SizedBox.shrink(),
          ),

          // ── Tita ──────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_floatCtrl, _shakeCtrl, _jumpCtrl]),
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeX, -_floatY.value + _jumpOffset(_jumpCtrl.value)),
              child:  child,
            ),
            child: GestureDetector(
              onTap: _openHelp,
              child: _buildCharacter(),
            ),
          ),
        ],
      ),
    );
  }

  void _openHelp() => showDialog(
    context: context,
    builder: (_) => const HelpDialog(),
  );

  Widget _buildCharacter() {
    return Container(
      width:  60,
      height: 80,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color:        _glowColor.withOpacity(0.45),
            blurRadius:   14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image.asset(
        _imagePath(),
        fit: BoxFit.contain,
      ),
    );
  }

  String _imagePath() {
    switch (_expr) {
      case _Expression.happy:    return 'assets/images/tita_happy.png';
      case _Expression.confused: return 'assets/images/tita_confused.png';
      case _Expression.excited:  return 'assets/images/tita_excited.png';
      case _Expression.watching: return 'assets/images/tita_watching.png';
      default:                   return 'assets/images/tita_neutral.png';
    }
  }

  Color get _glowColor {
    switch (widget.state) {
      case VampiritoState.error:   return AppTheme.red;
      case VampiritoState.success: return AppTheme.green;
      case VampiritoState.running: return AppTheme.cyan;
      default:                     return AppTheme.purple;
    }
  }

  // ── Globo de diálogo ──────────────────────────────────────────────────────

  Widget _buildBubble() {
    final c = _bubbleContent();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize:       MainAxisSize.min,
      children: [

        // ── Burbuja principal ──────────────────────────────────────────
        Container(
          constraints: const BoxConstraints(maxWidth: 250, minWidth: 110),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color:        AppTheme.currentLine,
            borderRadius: BorderRadius.circular(14),
            border:       Border.all(color: c.color.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color:      c.color.withOpacity(0.18),
                blurRadius: 14,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize:       MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(c.icon, size: 13, color: c.color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  c.text,
                  style: const TextStyle(
                    color:      AppTheme.foreground,
                    fontSize:   11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // ── Burbuja del tip ────────────────────────────────────────────
        if (c.tip != null) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 250, minWidth: 110),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color:        AppTheme.currentLine,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.yellow.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color:      AppTheme.yellow.withOpacity(0.12),
                  blurRadius: 10,
                  offset:     const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 13, color: AppTheme.yellow),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    c.tip!,
                    style: const TextStyle(
                      color:      AppTheme.yellow,
                      fontSize:   11,
                      fontFamily: 'monospace',
                      fontStyle:  FontStyle.italic,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Cola apuntando hacia Tita ──────────────────────────────────
        const SizedBox(height: 0),
        Padding(
          padding: const EdgeInsets.only(right: 18),
          child: CustomPaint(
            painter: _DownTailPainter(c.color.withOpacity(0.55)),
            size:    const Size(14, 10),
          ),
        ),
      ],
    );
  }

  _BubbleContent _bubbleContent() {
    switch (widget.state) {
      case VampiritoState.error:
        final lineas = (widget.errorMessage ?? '').split('\n');

        final descripcionLineas = lineas
            .where((l) => !l.trimLeft().startsWith('👉'))
            .map((l) => l.replaceAll('❌ ', '').trim())
            .where((l) => l.isNotEmpty)
            .join('\n');

        final pista = _tipFromError(widget.errorMessage ?? '');

        return _BubbleContent(
          text:  descripcionLineas.length > 200
              ? '${descripcionLineas.substring(0, 200)}...'
              : descripcionLineas,
          tip:   pista,
          color: AppTheme.red,
          icon:  Icons.pest_control,
        );

      case VampiritoState.success:
        return const _BubbleContent(
          text:  '¡Compilación exitosa! 🌿✨\nListo para ejecutar o simular.',
          tip:   null,
          color: AppTheme.green,
          icon:  Icons.check_circle_outline,
        );

      case VampiritoState.running:
        return const _BubbleContent(
          text:  '¡Compilando el programa...\nEspera un momento! 🔮',
          tip:   null,
          color: AppTheme.cyan,
          icon:  Icons.pending_outlined,
        );

      default:
        return const _BubbleContent(
          text:  '¡Hola! Tócame para ver\nla documentación 📚🌿',
          tip:   null,
          color: AppTheme.purple,
          icon:  Icons.help_outline,
        );
    }
  }

  String? _tipFromError(String msg) {
    if (msg.isEmpty) return null;

    final lineas     = msg.split('\n');
    final lineaPista = lineas
        .where((l) => l.trimLeft().startsWith('👉'))
        .map((l) => l.replaceAll('👉', '').trim())
        .firstOrNull;

    if (lineaPista != null && lineaPista.isNotEmpty) {
      final primeraParte = lineaPista.split('\n').first.trim();
      return primeraParte.length > 100
          ? '${primeraParte.substring(0, 100)}...'
          : primeraParte;
    }

    final m = msg.toLowerCase();
    if (m.contains('nunca le diste un valor') || m.contains('asign')) {
      return 'Define la variable antes de usarla: N = 10';
    }
    if (m.contains('demasiadas repeticiones') || m.contains('10,000')) {
      return 'Usa un número menor a 10,000 en tu variable.';
    }
    if (m.contains('mayor a 0') || m.contains('negativo')) {
      return 'La variable del REPETIR debe ser mayor a 0.';
    }
    if (m.contains('fin programa') || m.contains('primera línea')) {
      return 'Estructura: PROGRAMA "nombre" ... FIN PROGRAMA';
    }
    if (m.contains('sen') || m.contains('cos') || m.contains('tang')) {
      return 'Funciones: SEN(90)  COS(45)  TANG(30)';
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET 2 — VampiritoExecutionAnimation (animación al ejecutar)
// ═══════════════════════════════════════════════════════════════════════════

class VampiritoExecutionAnimation extends StatefulWidget {
  final bool         success;
  final String?      errorMessage;
  final VoidCallback onComplete;

  const VampiritoExecutionAnimation({
    Key? key,
    required this.success,
    required this.onComplete,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<VampiritoExecutionAnimation> createState() =>
      _VampiritoExecutionAnimationState();
}

class _VampiritoExecutionAnimationState
    extends State<VampiritoExecutionAnimation>
    with TickerProviderStateMixin {

  late final AnimationController _flyInCtrl;
  late final AnimationController _suspenseCtrl;
  late final AnimationController _sparkleCtrl;
  late final AnimationController _reactionCtrl;
  late final Animation<double>   _bounce;
  late final Animation<double>   _glow;
  late final AnimationController _shakeCtrl;
  late final AnimationController _flyOutCtrl;
  late final AnimationController _bannerCtrl;
  late final Animation<Offset>   _bannerSlide;

  _Expression _expr       = _Expression.excited;
  bool        _showBubble = false;
  bool        _isSuspense = false;

  static const _sparkleOffsets = [
    Offset(-28,  -8), Offset( 28, -12), Offset(-22,  18),
    Offset( 24,  14), Offset(  0, -32), Offset(-32,   4),
    Offset( 30,  -2), Offset(-10,  30), Offset( 12, -28),
  ];
  static const _sparkleColors = [
    AppTheme.cyan, AppTheme.yellow, AppTheme.green,
    AppTheme.cyan, AppTheme.yellow, AppTheme.purple,
    AppTheme.green, AppTheme.cyan, AppTheme.yellow,
  ];

  @override
  void initState() {
    super.initState();

    _flyInCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );

    _suspenseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 90),
    );

    _sparkleCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );

    _reactionCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    );
    _bounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -30.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -30.0, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _reactionCtrl, curve: Curves.easeInOut));

    _glow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _reactionCtrl, curve: Curves.easeOut),
    );

    _shakeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 550),
    );

    _flyOutCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );

    _bannerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 420),
    );
    _bannerSlide = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutBack));

    _runSequence();
  }

  Future<void> _runSequence() async {
    setState(() => _expr = _Expression.excited);
    await _flyInCtrl.forward();

    setState(() {
      _isSuspense = true;
      _expr       = _Expression.excited;
    });
    _suspenseCtrl.repeat(reverse: true);
    _sparkleCtrl.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 2800));

    _suspenseCtrl.stop();
    _sparkleCtrl.stop();
    setState(() => _isSuspense = false);

    await Future.delayed(const Duration(milliseconds: 80));
    setState(() {
      _expr       = widget.success ? _Expression.happy : _Expression.confused;
      _showBubble = true;
    });
    _bannerCtrl.forward();

    if (widget.success) {
      await _reactionCtrl.forward();
    } else {
      await _shakeCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    await Future.delayed(const Duration(milliseconds: 1400));

    await _bannerCtrl.reverse();
    setState(() => _showBubble = false);
    await Future.delayed(const Duration(milliseconds: 100));
    await _flyOutCtrl.forward();

    widget.onComplete();
  }

  @override
  void dispose() {
    _flyInCtrl.dispose();
    _suspenseCtrl.dispose();
    _sparkleCtrl.dispose();
    _reactionCtrl.dispose();
    _shakeCtrl.dispose();
    _flyOutCtrl.dispose();
    _bannerCtrl.dispose();
    super.dispose();
  }

  double get _suspenseTrembleX =>
      _isSuspense ? math.sin(_suspenseCtrl.value * math.pi) * 3.5 : 0;
  double get _suspenseTrembleY =>
      _isSuspense ? math.cos(_suspenseCtrl.value * math.pi * 2) * 2 : 0;

  double get _shakeX =>
      math.sin(_shakeCtrl.value * math.pi * 6) * 12 * (1 - _shakeCtrl.value);

  List<Widget> _buildSparkles() {
    return List.generate(_sparkleOffsets.length, (i) {
      final phase   = i / _sparkleOffsets.length;
      final rawT    = (_sparkleCtrl.value + phase) % 1.0;
      final opacity = math.sin(rawT * math.pi).clamp(0.0, 1.0);
      final size    = 4.0 + opacity * 4.0;
      final off     = _sparkleOffsets[i];
      final color   = _sparkleColors[i];

      return Positioned(
        left: 30 + off.dx - size / 2,
        top:  40 + off.dy - size / 2,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width:  size,
            height: size,
            decoration: BoxDecoration(
              color:     color,
              shape:     BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      color.withOpacity(0.7),
                  blurRadius: size * 1.5,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Imagen de Tita según expresión ────────────────────────────────────────

  String _imagePath(_Expression expr) {
    switch (expr) {
      case _Expression.happy:    return 'assets/images/tita_happy.png';
      case _Expression.confused: return 'assets/images/tita_confused.png';
      case _Expression.excited:  return 'assets/images/tita_excited.png';
      case _Expression.watching: return 'assets/images/tita_watching.png';
      default:                   return 'assets/images/tita_neutral.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;

    final startX  = size.width  - 76.0;
    final startY  = size.height - 120.0;
    final centerX = size.width  / 2 - 50.0;
    final centerY = size.height / 2 - 80.0;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _flyInCtrl, _suspenseCtrl, _sparkleCtrl,
        _reactionCtrl, _shakeCtrl, _flyOutCtrl, _bannerCtrl,
      ]),
      builder: (context, _) {
        double t, x, y, scale;

        if (!_flyOutCtrl.isAnimating && _flyOutCtrl.value == 0) {
          t     = CurvedAnimation(parent: _flyInCtrl, curve: Curves.easeOutBack).value;
          x     = lerpDouble(startX, centerX, t)!;
          y     = lerpDouble(startY, centerY, t)!;
          scale = lerpDouble(1.0, 2.2, t)!;
        } else {
          t     = CurvedAnimation(parent: _flyOutCtrl, curve: Curves.easeInBack).value;
          x     = lerpDouble(centerX, startX, t)!;
          y     = lerpDouble(centerY, startY, t)!;
          scale = lerpDouble(2.2, 1.0, t)!;
        }

        final bounceOffset = _reactionCtrl.isAnimating ? _bounce.value : 0.0;
        final shakeOffset  = _shakeCtrl.isAnimating    ? _shakeX       : 0.0;
        final trembleX     = _suspenseTrembleX;
        final trembleY     = _suspenseTrembleY;

        final Color  glowColor;
        final double glowRadius;

        if (_isSuspense) {
          final pulse = math.sin(_sparkleCtrl.value * math.pi).abs();
          glowColor  = AppTheme.cyan;
          glowRadius = 10.0 + pulse * 22.0;
        } else {
          glowColor  = widget.success ? AppTheme.green : AppTheme.red;
          glowRadius = widget.success ? 10.0 + _glow.value * 30.0 : 14.0;
        }

        return Stack(
          children: [

            // ── Fondo semitransparente ─────────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withOpacity(_flyInCtrl.value * 0.30),
                ),
              ),
            ),

            // ── BANNER SUPERIOR ────────────────────────────────────────
            if (_showBubble)
              Positioned(
                top:   0,
                left:  0,
                right: 0,
                child: SlideTransition(
                  position: _bannerSlide,
                  child: RepaintBoundary(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Container(
                          width:   double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color:        AppTheme.currentLine,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: glowColor.withOpacity(0.75),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:      glowColor.withOpacity(0.30),
                                blurRadius: 20,
                                offset:     const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width:  36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:  glowColor.withOpacity(0.15),
                                  shape:  BoxShape.circle,
                                  border: Border.all(
                                      color: glowColor.withOpacity(0.5),
                                      width: 1.5),
                                ),
                                child: Icon(
                                  widget.success
                                      ? Icons.check_circle_outline
                                      : Icons.bug_report_outlined,
                                  color: glowColor,
                                  size:  20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  widget.success
                                      ? '¡Perfecto! 🌿✨  Todo salió bien.'
                                      : _cleanErrorText(widget.errorMessage),
                                  style: TextStyle(
                                    color:      widget.success
                                        ? AppTheme.green
                                        : AppTheme.foreground,
                                    fontSize:   13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    height:     1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── TITA + lucecitas ───────────────────────────────────────
            Positioned(
              left: x + shakeOffset + trembleX,
              top:  y + bounceOffset + trembleY,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width:  60,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color:        glowColor.withOpacity(
                                _isSuspense ? 0.45 : 0.3 + _glow.value * 0.5),
                            blurRadius:   glowRadius,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        _imagePath(_expr),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  if (_isSuspense) ..._buildSparkles(),
                ],
              ),
            ),

          ],
        );
      },
    );
  }

  String _cleanErrorText(String? msg) {
    if (msg == null || msg.isEmpty) return '¡Hay un error!\nRevisa el código.';
    final firstLine = msg
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => msg)
        .replaceAll('❌ ', '')
        .trim();
    return firstLine.length > 80 ? '${firstLine.substring(0, 80)}…' : firstLine;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINTER — Cola del globo apuntando hacia abajo
// ═══════════════════════════════════════════════════════════════════════════

class _DownTailPainter extends CustomPainter {
  final Color color;
  const _DownTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppTheme.currentLine;
    final border = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0,                0)
      ..lineTo(size.width,       0)
      ..lineTo(size.width * 0.8, size.height)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(_DownTailPainter old) => old.color != color;
}