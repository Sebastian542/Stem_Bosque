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

  // Float suave (siempre activo)
  late final AnimationController _floatCtrl;
  late final Animation<double>   _floatY;

  // Shake horizontal (errores)
  late final AnimationController _shakeCtrl;

  // Jump (éxito)
  late final AnimationController _jumpCtrl;

  // Escala del globo (entrar / salir)
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
        // Esconder globo automáticamente después de 4s
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

          // ── Vampirito ──────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color:        _glowColor.withOpacity(0.45),
            blurRadius:   14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(painter: _VampirePainter(_expr)),
    );
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

        // ── Cola apuntando hacia el vampirito ──────────────────────────
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
          text:  '¡Compilación exitosa! 🦇✨\nListo para ejecutar o simular.',
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
          text:  '¡Hola! Tócame para ver\nla documentación 📚🦇',
          tip:   null,
          color: AppTheme.purple,
          icon:  Icons.help_outline,
        );
    }
  }

  String? _tipFromError(String msg) {
    if (msg.isEmpty) return null;

    final lineas    = msg.split('\n');
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
  final bool    success;
  final String? errorMessage;
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

  // Fase 1: vuela al centro
  late final AnimationController _flyInCtrl;

  // Fase 2: SUSPENSO — temblor continuo mientras "procesa"
  late final AnimationController _suspenseCtrl;   // repite rápido → temblor
  late final AnimationController _sparkleCtrl;    // repite lento  → lucecitas pulsan

  // Fase 3: reacción
  late final AnimationController _reactionCtrl;
  late final Animation<double>   _bounce;
  late final Animation<double>   _glow;

  // Shake para error
  late final AnimationController _shakeCtrl;

  // Fase 4: regresa
  late final AnimationController _flyOutCtrl;

  // Banner superior: desliza desde arriba
  late final AnimationController _bannerCtrl;
  late final Animation<Offset>   _bannerSlide;

  _Expression _expr        = _Expression.excited;
  bool        _showBubble  = false;
  bool        _isSuspense  = false;   // activa temblor + lucecitas

  // Posiciones fijas de las lucecitas relativas al centro del vampirito
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

    // ── Fly in ──────────────────────────────────────────────────────────
    _flyInCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );

    // ── Suspenso: temblor muy rápido ────────────────────────────────────
    _suspenseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 90),   // ciclo rápido = vibración
    );

    // ── Lucecitas: pulso más lento ──────────────────────────────────────
    _sparkleCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );

    // ── Reacción ────────────────────────────────────────────────────────
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

    // ── Shake error ─────────────────────────────────────────────────────
    _shakeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 550),
    );

    // ── Fly out ─────────────────────────────────────────────────────────
    _flyOutCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );

    // ── Banner superior ──────────────────────────────────────────────────
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
    // ── Fase 1: vuela al centro ──────────────────────────────────────────
    setState(() => _expr = _Expression.excited);
    await _flyInCtrl.forward();

    // ── Fase 2: SUSPENSO (2.8 s de tensión) ─────────────────────────────
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

    // ── Fase 3: REACCIÓN — banner baja desde arriba ───────────────────────
    await Future.delayed(const Duration(milliseconds: 80));
    setState(() {
      _expr      = widget.success ? _Expression.happy : _Expression.confused;
      _showBubble = true;
    });
    _bannerCtrl.forward();   // banner entra desde arriba

    if (widget.success) {
      await _reactionCtrl.forward();
    } else {
      await _shakeCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Mantener banner visible
    await Future.delayed(const Duration(milliseconds: 1400));

    // ── Fase 4: banner sube, luego vampirito regresa ──────────────────────
    await _bannerCtrl.reverse();          // banner sale hacia arriba
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

  // Temblor de suspenso: sacudida fina en X e Y
  double get _suspenseTrembleX =>
      _isSuspense ? math.sin(_suspenseCtrl.value * math.pi) * 3.5 : 0;
  double get _suspenseTrembleY =>
      _isSuspense ? math.cos(_suspenseCtrl.value * math.pi * 2) * 2 : 0;

  // Shake de error
  double get _shakeX =>
      math.sin(_shakeCtrl.value * math.pi * 6) * 12 * (1 - _shakeCtrl.value);

  // Lucecitas: cada una tiene un desfase de fase para que pulsen escalonadas
  List<Widget> _buildSparkles() {
    return List.generate(_sparkleOffsets.length, (i) {
      final phase    = i / _sparkleOffsets.length;
      final rawT     = (_sparkleCtrl.value + phase) % 1.0;
      final opacity  = math.sin(rawT * math.pi).clamp(0.0, 1.0);
      final size     = 4.0 + opacity * 4.0;
      final off      = _sparkleOffsets[i];
      final color    = _sparkleColors[i];

      return Positioned(
        // El vampirito mide 60×80; centramos en (30, 40)
        left: 30 + off.dx - size / 2,
        top:  40 + off.dy - size / 2,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width:      size,
            height:     size,
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
        // ── Posición e interpolación ───────────────────────────────────
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

        // ── Offsets adicionales ────────────────────────────────────────
        final bounceOffset = _reactionCtrl.isAnimating ? _bounce.value : 0.0;
        final shakeOffset  = _shakeCtrl.isAnimating    ? _shakeX       : 0.0;
        final trembleX     = _suspenseTrembleX;
        final trembleY     = _suspenseTrembleY;

        // ── Glow según fase ────────────────────────────────────────────
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
                              // Icono
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
                              // Texto
                              Expanded(
                                child: Text(
                                  widget.success
                                      ? '¡Perfecto! 🦇✨  Todo salió bien.'
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

            // ── VAMPIRITO + lucecitas (sin burbuja) ────────────────────
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
                      child: CustomPaint(painter: _VampirePainter(_expr)),
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

  /// Limpia el texto de error para mostrarlo sin prefijos ni saltos raros
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
// PAINTER — Vampirito con 5 expresiones
// ═══════════════════════════════════════════════════════════════════════════

class _VampirePainter extends CustomPainter {
  final _Expression expr;
  const _VampirePainter(this.expr);

  static const _purple = AppTheme.purple;
  static const _cape   = Color(0xFF6272a4);
  static const _skin   = Color(0xFFe8d5f0);
  static const _dark   = AppTheme.background;
  static const _red    = AppTheme.red;
  static const _white  = AppTheme.foreground;
  static const _cyan   = AppTheme.cyan;
  static const _green  = AppTheme.green;
  static const _yellow = AppTheme.yellow;
  static const _pink   = Color(0xFFffb3d1);

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w) => Paint()
    ..color       = c
    ..style       = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap   = StrokeCap.round
    ..strokeJoin  = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _drawBase(canvas, w, h);
    _drawFace(canvas, w, h);
    _drawChest(canvas, w, h);
    _drawExtras(canvas, w, h);
  }

  // ── BASE ──────────────────────────────────────────────────────────────────

  void _drawBase(Canvas canvas, double w, double h) {
    // Capa
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.10, h * 0.35)
        ..quadraticBezierTo(0, h * 0.65, w * 0.05, h)
        ..lineTo(w * 0.95, h)
        ..quadraticBezierTo(w, h * 0.65, w * 0.90, h * 0.35)
        ..close(),
      _fill(_cape),
    );

    // Alitas de la capa
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.05, h)
        ..quadraticBezierTo(0, h * 0.84, 0, h * 0.70)
        ..quadraticBezierTo(w * 0.08, h * 0.80, w * 0.18, h)
        ..close(),
      _fill(_dark),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.95, h)
        ..quadraticBezierTo(w, h * 0.84, w, h * 0.70)
        ..quadraticBezierTo(w * 0.92, h * 0.80, w * 0.82, h)
        ..close(),
      _fill(_dark),
    );

    // Cuerpo
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.48, w * 0.56, h * 0.44),
        const Radius.circular(10),
      ),
      _fill(_purple),
    );

    // Cuello
    canvas.drawRect(
      Rect.fromLTWH(w * 0.38, h * 0.37, w * 0.24, h * 0.14),
      _fill(_skin),
    );

    // Cabeza
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, h * 0.05, w * 0.64, h * 0.36),
      _fill(_skin),
    );

    // Orejas puntiagudas
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.20, h * 0.15)
        ..lineTo(w * 0.13, h * 0.02)
        ..lineTo(w * 0.30, h * 0.11)
        ..close(),
      _fill(_skin),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.80, h * 0.15)
        ..lineTo(w * 0.87, h * 0.02)
        ..lineTo(w * 0.70, h * 0.11)
        ..close(),
      _fill(_skin),
    );
  }

  // ── CARA según expresión ──────────────────────────────────────────────────

  void _drawFace(Canvas canvas, double w, double h) {
    switch (expr) {
      case _Expression.neutral:  _neutral(canvas, w, h);  break;
      case _Expression.happy:    _happy(canvas, w, h);    break;
      case _Expression.confused: _confused(canvas, w, h); break;
      case _Expression.excited:  _excited(canvas, w, h);  break;
      case _Expression.watching: _watching(canvas, w, h); break;
    }
  }

  void _normalEyes(Canvas canvas, double w, double h, {double pdx = 0}) {
    canvas.drawOval(Rect.fromLTWH(w * 0.28, h * 0.14, w * 0.18, h * 0.13), _fill(_white));
    canvas.drawCircle(Offset(w * 0.37 + pdx, h * 0.21), w * 0.046, _fill(_red));

    canvas.drawOval(Rect.fromLTWH(w * 0.54, h * 0.14, w * 0.18, h * 0.13), _fill(_white));
    canvas.drawCircle(Offset(w * 0.63 + pdx, h * 0.21), w * 0.046, _fill(_red));
  }

  void _fangs(Canvas canvas, double w, double h, double yBase) {
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.43, yBase)
        ..lineTo(w * 0.40, yBase + h * 0.055)
        ..lineTo(w * 0.46, yBase)
        ..close(),
      _fill(_white),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.57, yBase)
        ..lineTo(w * 0.54, yBase + h * 0.055)
        ..lineTo(w * 0.60, yBase)
        ..close(),
      _fill(_white),
    );
  }

  // ── NEUTRAL ───────────────────────────────────────────────────────────────

  void _neutral(Canvas canvas, double w, double h) {
    canvas.drawLine(Offset(w * 0.28, h * 0.12), Offset(w * 0.43, h * 0.145),
        _stroke(_purple, 2));
    canvas.drawLine(Offset(w * 0.57, h * 0.145), Offset(w * 0.72, h * 0.12),
        _stroke(_purple, 2));

    _normalEyes(canvas, w, h);

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.37, h * 0.32)
        ..quadraticBezierTo(w * 0.50, h * 0.295, w * 0.63, h * 0.32),
      _stroke(_red.withOpacity(0.7), 1.5),
    );
    _fangs(canvas, w, h, h * 0.315);
  }

  // ── HAPPY ─────────────────────────────────────────────────────────────────

  void _happy(Canvas canvas, double w, double h) {
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, h * 0.135)
        ..quadraticBezierTo(w * 0.355, h * 0.078, w * 0.43, h * 0.135),
      _stroke(_purple, 2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.57, h * 0.135)
        ..quadraticBezierTo(w * 0.645, h * 0.078, w * 0.72, h * 0.135),
      _stroke(_purple, 2),
    );

    canvas.drawArc(Rect.fromLTWH(w * 0.28, h * 0.10, w * 0.18, h * 0.14),
        math.pi, math.pi, false, _stroke(_dark, 2.5));
    canvas.drawArc(Rect.fromLTWH(w * 0.54, h * 0.10, w * 0.18, h * 0.14),
        math.pi, math.pi, false, _stroke(_dark, 2.5));

    canvas.drawOval(
        Rect.fromLTWH(w * 0.18, h * 0.21, w * 0.13, h * 0.07),
        _fill(_pink.withOpacity(0.65)));
    canvas.drawOval(
        Rect.fromLTWH(w * 0.69, h * 0.21, w * 0.13, h * 0.07),
        _fill(_pink.withOpacity(0.65)));

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h * 0.30)
        ..quadraticBezierTo(w * 0.50, h * 0.395, w * 0.70, h * 0.30),
      _stroke(_red.withOpacity(0.85), 2),
    );
    _fangs(canvas, w, h, h * 0.295);
  }

  // ── CONFUSED ──────────────────────────────────────────────────────────────

  void _confused(Canvas canvas, double w, double h) {
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, h * 0.09)
        ..quadraticBezierTo(w * 0.355, h * 0.052, w * 0.43, h * 0.095),
      _stroke(_purple, 2),
    );
    canvas.drawLine(
      Offset(w * 0.57, h * 0.155),
      Offset(w * 0.72, h * 0.145),
      _stroke(_purple, 2),
    );

    canvas.drawOval(Rect.fromLTWH(w * 0.27, h * 0.12, w * 0.20, h * 0.15), _fill(_white));
    canvas.drawCircle(Offset(w * 0.37, h * 0.20), w * 0.052, _fill(_red));

    canvas.drawOval(Rect.fromLTWH(w * 0.54, h * 0.14, w * 0.16, h * 0.12), _fill(_white));
    canvas.drawCircle(Offset(w * 0.62, h * 0.205), w * 0.038, _fill(_red));

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.35, h * 0.30)
        ..lineTo(w * 0.41, h * 0.335)
        ..lineTo(w * 0.47, h * 0.30)
        ..lineTo(w * 0.53, h * 0.335)
        ..lineTo(w * 0.59, h * 0.30)
        ..lineTo(w * 0.65, h * 0.335),
      _stroke(_red.withOpacity(0.75), 1.5),
    );
  }

  // ── EXCITED ───────────────────────────────────────────────────────────────

  void _excited(Canvas canvas, double w, double h) {
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.27, h * 0.085)
        ..quadraticBezierTo(w * 0.355, h * 0.045, w * 0.44, h * 0.095),
      _stroke(_purple, 2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.56, h * 0.095)
        ..quadraticBezierTo(w * 0.645, h * 0.045, w * 0.73, h * 0.085),
      _stroke(_purple, 2),
    );

    canvas.drawOval(Rect.fromLTWH(w * 0.26, h * 0.12, w * 0.21, h * 0.15), _fill(_white));
    canvas.drawCircle(Offset(w * 0.37, h * 0.20), w * 0.058, _fill(_red));
    canvas.drawCircle(Offset(w * 0.395, h * 0.178), w * 0.020, _fill(_white));

    canvas.drawOval(Rect.fromLTWH(w * 0.53, h * 0.12, w * 0.21, h * 0.15), _fill(_white));
    canvas.drawCircle(Offset(w * 0.64, h * 0.20), w * 0.058, _fill(_red));
    canvas.drawCircle(Offset(w * 0.665, h * 0.178), w * 0.020, _fill(_white));

    canvas.drawOval(Rect.fromLTWH(w * 0.38, h * 0.28, w * 0.24, h * 0.10), _fill(_dark));
    canvas.drawOval(Rect.fromLTWH(w * 0.38, h * 0.28, w * 0.24, h * 0.10),
        _stroke(_red.withOpacity(0.6), 1.5));
  }

  // ── WATCHING ──────────────────────────────────────────────────────────────

  void _watching(Canvas canvas, double w, double h) {
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, h * 0.125)
        ..quadraticBezierTo(w * 0.355, h * 0.088, w * 0.43, h * 0.128),
      _stroke(_purple, 2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.57, h * 0.118)
        ..quadraticBezierTo(w * 0.645, h * 0.080, w * 0.72, h * 0.120),
      _stroke(_purple, 2),
    );

    _normalEyes(canvas, w, h, pdx: w * 0.04);

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.38, h * 0.315)
        ..quadraticBezierTo(w * 0.50, h * 0.325, w * 0.62, h * 0.315),
      _stroke(_red.withOpacity(0.65), 1.5),
    );
    _fangs(canvas, w, h, h * 0.312);
  }

  // ── Icono en el pecho ─────────────────────────────────────────────────────

  void _drawChest(Canvas canvas, double w, double h) {
    String symbol;
    Color  color;
    switch (expr) {
      case _Expression.happy:    symbol = '✓'; color = _green;  break;
      case _Expression.confused: symbol = '!'; color = _yellow; break;
      case _Expression.excited:  symbol = '▶'; color = _cyan;   break;
      case _Expression.watching: symbol = '~'; color = _cyan;   break;
      default:                   symbol = '?'; color = _cyan;   break;
    }

    final tp = TextPainter(
      text: TextSpan(
        text:  symbol,
        style: TextStyle(
          color:      color,
          fontSize:   15,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w * 0.50 - tp.width / 2, h * 0.575));
  }

  // ── Extras por expresión ──────────────────────────────────────────────────

  void _drawExtras(Canvas canvas, double w, double h) {
    switch (expr) {
      case _Expression.happy:    _sparkles(canvas, w, h);     break;
      case _Expression.confused: _sweatDrop(canvas, w, h);    break;
      case _Expression.excited:  _excitedLines(canvas, w, h); break;
      default: break;
    }
  }

  void _sparkles(Canvas canvas, double w, double h) {
    _star(canvas, Offset(w * 0.10, h * 0.08), w * 0.030, _yellow);
    _star(canvas, Offset(w * 0.90, h * 0.06), w * 0.022, _cyan);
    _star(canvas, Offset(w * 0.88, h * 0.19), w * 0.018, _yellow);
  }

  void _star(Canvas canvas, Offset center, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final dist  = i.isEven ? r : r * 0.45;
      final p     = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, _fill(color));
  }

  void _sweatDrop(Canvas canvas, double w, double h) {
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.83, h * 0.04)
        ..quadraticBezierTo(w * 0.88, h * 0.10, w * 0.83, h * 0.135)
        ..quadraticBezierTo(w * 0.78, h * 0.10, w * 0.83, h * 0.04)
        ..close(),
      _fill(AppTheme.cyan.withOpacity(0.85)),
    );
  }

  void _excitedLines(Canvas canvas, double w, double h) {
    final lp = _stroke(_cyan.withOpacity(0.7), 1.5);
    canvas.drawLine(Offset(w * 0.04, h * 0.10), Offset(w * 0.14, h * 0.15), lp);
    canvas.drawLine(Offset(w * 0.04, h * 0.17), Offset(w * 0.14, h * 0.19), lp);
    canvas.drawLine(Offset(w * 0.96, h * 0.10), Offset(w * 0.86, h * 0.15), lp);
    canvas.drawLine(Offset(w * 0.96, h * 0.17), Offset(w * 0.86, h * 0.19), lp);
  }

  @override
  bool shouldRepaint(_VampirePainter old) => old.expr != expr;
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINTER — Cola del globo apuntando hacia abajo
// ═══════════════════════════════════════════════════════════════════════════

class _DownTailPainter extends CustomPainter {
  final Color color;
  const _DownTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final fill   = Paint()..color = AppTheme.currentLine;
    final border = Paint()
      ..color       = color
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(0,                0)
      ..lineTo(size.width,       0)
      ..lineTo(size.width * 0.6, size.height)
      ..close();

    canvas.drawPath(path, border);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_DownTailPainter old) => old.color != color;
}