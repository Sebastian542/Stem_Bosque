import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'help_dialog.dart';
import '../../compiler/syntax_validator.dart' show ErrorCodigo;

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
  final String?  exampleTitle; // cuadrito "así se escribe": título
  final String?  exampleCode;  // ... y el código de ejemplo
  const _BubbleContent({
    required this.text,
    required this.tip,
    required this.color,
    required this.icon,
    this.exampleTitle,
    this.exampleCode,
  });
}

/// Un mensaje de error de SyntaxValidator separado en sus partes.
class _ErrorPartes {
  final String  descripcion;
  final String? pista;
  final String? ejemploTitulo;
  final String? ejemploCodigo;
  const _ErrorPartes({
    required this.descripcion,
    required this.pista,
    required this.ejemploTitulo,
    required this.ejemploCodigo,
  });
}

/// Pinta un ejemplo de código con los mismos colores que el editor.
TextSpan _codigoColoreado(String codigo) {
  const estructura = {'PROGRAMA', 'FIN', 'SI', 'ENTONCES', 'REPETIR', 'VECES'};
  const ordenes    = {'GIRAR', 'AVANZAR'};
  const funciones  = {'SEN', 'COS', 'TANG'};
  final partes = RegExp(r'"[^"]*"|[0-9]+(?:\.[0-9]+)?|[A-Za-z_][A-Za-z0-9_]*|\s+|.');

  TextStyle estilo(String t) {
    final m = t.toUpperCase();
    if (t.startsWith('"'))                    return const TextStyle(color: AppTheme.yellow);
    if (RegExp(r'^[0-9]').hasMatch(t))        return const TextStyle(color: AppTheme.purple);
    if (estructura.contains(m))               return const TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold);
    if (ordenes.contains(m))                  return const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold);
    if (funciones.contains(m))                return const TextStyle(color: AppTheme.orange);
    if (RegExp(r'^[A-Za-z_]').hasMatch(t))    return const TextStyle(color: AppTheme.green);
    return const TextStyle(color: AppTheme.foreground);
  }

  final lineas = codigo.split('\n');
  final spans  = <InlineSpan>[];
  for (var i = 0; i < lineas.length; i++) {
    if (i > 0) spans.add(const TextSpan(text: '\n'));
    final linea = lineas[i];
    final iNota = linea.indexOf('//');
    final cod   = iNota >= 0 ? linea.substring(0, iNota) : linea;
    for (final m in partes.allMatches(cod)) {
      final t = m.group(0)!;
      spans.add(TextSpan(text: t, style: estilo(t)));
    }
    if (iNota >= 0) {
      spans.add(TextSpan(
        text: linea.substring(iNota),
        style: const TextStyle(color: AppTheme.comment),
      ));
    }
  }
  return TextSpan(children: spans);
}

// ═══════════════════════════════════════════════════════════════════════════
// TAMAÑO E IMÁGENES DE TITA (compartido por la mascota y la animación)
// ═══════════════════════════════════════════════════════════════════════════

/// Tamaño de Tita en pantalla. La caja es 4:3 (alto = ancho × 4/3) y los PNG se
/// dibujan con BoxFit.contain dentro de ella.
class _TitaSize {
  static const double minWidth     = 72;
  static const double maxWidth     = 108;
  static const double aspect       = 4 / 3;
  static const double maxExecScale = 1.8; // escala máxima en la animación de ejecución

  static double width(BuildContext context) =>
      (MediaQuery.sizeOf(context).shortestSide * 0.20).clamp(minWidth, maxWidth).toDouble();
}

/// Rutas y carga de las 5 expresiones. Todas se decodifican al mismo ancho (el
/// máximo que llega a dibujarse) para no mantener en memoria más píxeles de los
/// necesarios, y para que la mascota y la animación compartan la misma caché.
class _TitaImages {
  static const _paths = <_Expression, String>{
    _Expression.neutral:  'assets/images/tita_neutral.webp',
    _Expression.happy:    'assets/images/tita_happy.webp',
    _Expression.confused: 'assets/images/tita_confused.webp',
    _Expression.excited:  'assets/images/tita_excited.webp',
    _Expression.watching: 'assets/images/tita_watching.webp',
  };

  static int cacheWidth(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (_TitaSize.maxWidth * _TitaSize.maxExecScale * dpr).ceil();
  }

  static ImageProvider provider(_Expression e, int cacheWidth) =>
      ResizeImage(AssetImage(_paths[e]!), width: cacheWidth);

  static Future<void> precacheAll(BuildContext context) {
    final w = cacheWidth(context);
    return Future.wait([
      for (final e in _Expression.values)
        precacheImage(provider(e, w), context),
    ]);
  }

  /// Imagen de Tita. gaplessPlayback evita el parpadeo al cambiar de expresión.
  static Widget image(BuildContext context, _Expression e) => Image(
        image:           provider(e, cacheWidth(context)),
        fit:             BoxFit.contain,
        gaplessPlayback: true,
        filterQuality:   FilterQuality.medium,
        errorBuilder:    (_, __, ___) =>
            const Icon(Icons.pets, color: AppTheme.comment, size: 40),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET 1 — VampiritoPet (mascota permanente en la UI)
// ═══════════════════════════════════════════════════════════════════════════

class VampiritoPet extends StatefulWidget {
  final VampiritoState state;
  final bool           isTyping;

  /// Los errores del programa. Tita los cuenta en una insignia roja y solo los
  /// muestra (en un cuadro, o en una lista si son varios) cuando se la toca.
  final List<ErrorCodigo> errores;

  /// Se llama con el número de línea cuando se toca un error de la lista.
  final void Function(int linea)? onIrALinea;

  const VampiritoPet({
    super.key,
    required this.state,
    this.errores = const [],
    this.onIrALinea,
    this.isTyping = false,
  });

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

  // "Boing": Tita se aplasta un poquito (de arriba hacia abajo) y vuelve a su
  // forma, cada vez que cambia de cara o dice algo nuevo, y de vez en cuando
  // mientras habla.
  late final AnimationController _boingCtrl;
  Timer? _boingTimer;

  _Expression _expr       = _Expression.neutral;
  bool        _showBubble = false;

  bool   _abierto      = false; // el cuadro de errores está abierto
  String _firmaErrores = '';    // resumen de los errores, para saber si cambiaron

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2000),
    );
    _floatY = Tween<double>(begin: 0, end: 3.5).animate(
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

    _boingCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 450),
    );

    _bubbleCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 280),
    );

    _firmaErrores = _firma(widget.errores);
    _applyState(widget.state, initial: true);
  }

  int? _precachedWidth;
  bool _sinAnimaciones = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    if (sinAnimaciones != _sinAnimaciones) {
      _sinAnimaciones = sinAnimaciones;
      _flotar();
    }

    // Decodifica las 5 expresiones antes de necesitarlas: sin esto, la primera
    // vez que aparece cada una hay un parpadeo mientras se decodifica el PNG.
    final w = _TitaImages.cacheWidth(context);
    if (_precachedWidth != w) {
      _precachedWidth = w;
      _TitaImages.precacheAll(context);
    }
  }

  @override
  void didUpdateWidget(VampiritoPet old) {
    super.didUpdateWidget(old);

    // Al empezar a escribir, el cuadro de errores se esconde otra vez.
    if (!old.isTyping && widget.isTyping) _cerrarTarjeta();
    if (old.isTyping != widget.isTyping) _flotar();
    // Sin errores no hay nada que mostrar.
    if (widget.errores.isEmpty) _cerrarTarjeta();

    final firma = _firma(widget.errores);
    if (old.state != widget.state || firma != _firmaErrores) {
      _firmaErrores = firma;
      _applyState(widget.state);

      // Un error nuevo: Tita se sacude (y la insignia salta al cambiar el número).
      if (widget.state == VampiritoState.error &&
          (old.state != VampiritoState.error ||
              widget.errores.length > old.errores.length)) {
        _shakeCtrl.forward(from: 0);
      }
      // ¡Boing! Al cambiar de cara siempre; con algo nuevo que decir, solo si no
      // se está escribiendo (mientras se teclea, los errores cambian a cada letra).
      if (old.state != widget.state || !widget.isTyping) _boing();
    }
  }

  @override
  void dispose() {
    _boingTimer?.cancel();
    _boingCtrl.dispose();
    _floatCtrl.dispose();
    _shakeCtrl.dispose();
    _jumpCtrl.dispose();
    _bubbleCtrl.dispose();
    super.dispose();
  }

  void _boing() {
    if (mounted) _boingCtrl.forward(from: 0);
  }

  /// Cuánto se aplasta Tita en este instante: baja hasta un 8 % de su alto y
  /// vuelve a 0 (nunca se estira de más).
  double get _boingK => math.sin(_boingCtrl.value * math.pi) * 0.08;

  // ── Máquina de estados ────────────────────────────────────────────────────

  void _applyState(VampiritoState state, {bool initial = false}) {
    _Expression newExpr;
    bool        bubble;

    if (state != VampiritoState.error) _abierto = false;

    switch (state) {
      case VampiritoState.idle:
        newExpr = _Expression.neutral;
        bubble  = false;
        break;

      case VampiritoState.watching:
        newExpr = _Expression.watching;
        bubble  = false;
        break;

      case VampiritoState.error:
        // Con errores Tita pone cara de confundida y muestra la insignia roja;
        // el cuadro con los detalles solo sale si se la toca.
        newExpr = _Expression.confused;
        bubble  = _abierto && widget.errores.isNotEmpty;
        break;

      case VampiritoState.running:
        newExpr = _Expression.excited;
        bubble  = true;
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

    _setFloatSpeed(state == VampiritoState.running ? 500 : 2000);

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

    // Mientras habla, de vez en cuando vuelve a hacer "boing" para sentirse viva.
    _boingTimer?.cancel();
    if (bubble) {
      _boingTimer = Timer.periodic(const Duration(seconds: 9), (_) {
        if (mounted && _showBubble) _boing();
      });
    }
  }

  void _setFloatSpeed(int ms) {
    _floatCtrl.duration = Duration(milliseconds: ms);
    _flotar();
  }

  /// Tita flota unas cuantas veces y vuelve a quedarse quieta. Una animación
  /// sin fin obliga a dibujar la pantalla en cada fotograma aunque nada cambie.
  /// Mientras se ejecuta el programa sí flota sin parar.
  void _flotar() {
    if (widget.isTyping || _sinAnimaciones) {
      _floatCtrl.stop();
      _floatCtrl.value = 0;
      return;
    }
    _floatCtrl.repeat(
      reverse: true,
      count: widget.state == VampiritoState.running ? null : 6,
    );
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

  // ── Errores: una insignia roja, y el cuadro solo si se toca ───────────────

  /// Resumen de los errores: sirve para saber si cambiaron.
  String _firma(List<ErrorCodigo> errores) =>
      errores.map((e) => '${e.linea}:${e.mensaje}').join('\u0001');

  /// Un toque en Tita: con errores abre (o cierra) el cuadro; sin errores, la guía.
  void _alTocarTita() {
    if (widget.state == VampiritoState.error && widget.errores.isNotEmpty) {
      _abierto ? _cerrarTarjeta() : _abrirTarjeta();
    } else {
      _openHelp();
    }
  }

  void _abrirTarjeta() {
    if (_abierto) return;
    setState(() {
      _abierto    = true;
      _showBubble = true;
    });
  }

  void _cerrarTarjeta() {
    if (!_abierto) return;
    setState(() {
      _abierto    = false;
      _showBubble = false;
    });
  }

  /// La notificación roja con la cantidad de errores (salta al cambiar el número).
  Widget _insignia() {
    final n = widget.errores.length;
    return TweenAnimationBuilder<double>(
      key:      ValueKey(n),
      tween:    Tween<double>(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve:    Curves.elasticOut,
      builder:  (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding:     const EdgeInsets.symmetric(horizontal: 6),
        alignment:   Alignment.center,
        decoration: BoxDecoration(
          color:        AppTheme.red,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppTheme.background, width: 2),
        ),
        child: Text(
          n > 9 ? '9+' : '$n',
          style: AppTheme.fuente(
            fontSize:   12,
            fontWeight: FontWeight.w900,
            color:      Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titaW = _TitaSize.width(context);
    final titaH = titaW * _TitaSize.aspect;

    // Tita está a 16 px del borde derecho: hasta el borde izquierdo (con 8 px de
    // margen) es todo el ancho que tiene el cuadro.
    final disponible = MediaQuery.sizeOf(context).width - 16 - 8;

    // El cuadro sale de lado, a la altura de su cara: sube hasta que la colita
    // (28 px sobre su base) queda donde Tita tiene la cabeza (~74 % de su alto).
    final subirGlobo = math.max(0.0, titaH * 0.74 - 28);

    // Un toque fuera del cuadro lo cierra (y el toque sigue su camino: se puede
    // tocar el editor al mismo tiempo).
    return TapRegion(
      onTapOutside: (_) => _cerrarTarjeta(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: disponible),
        child: Row(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Cuadro (a la izquierda de Tita) ──────────────────────────
            Flexible(
              child: AnimatedSwitcher(
                duration:          const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale:     CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  alignment: Alignment.centerRight, // "nace" de Tita
                  child:     FadeTransition(opacity: anim, child: child),
                ),
                child: _showBubble
                    ? Padding(
                        key:     ValueKey('${widget.state}_${widget.errores.length}'),
                        padding: EdgeInsets.only(bottom: subirGlobo),
                        // Los mensajes cortos (compilando, éxito) dejan pasar los
                        // toques. El cuadro de errores no: tiene botones y una lista.
                        child: IgnorePointer(
                          ignoring: widget.state != VampiritoState.error,
                          child:    _buildBubble(disponible - titaW),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // ── Tita (se desvanece mientras se escribe) ──────────────────
            AnimatedOpacity(
              opacity:  widget.isTyping ? 0.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedBuilder(
                animation:
                    Listenable.merge([_floatCtrl, _shakeCtrl, _jumpCtrl, _boingCtrl]),
                builder: (_, child) {
                  final k = _boingK;
                  return Transform.translate(
                    offset: Offset(_shakeX, -_floatY.value + _jumpOffset(_jumpCtrl.value)),
                    // Se aplasta desde arriba hacia los pies (que no se mueven).
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.diagonal3Values(1, 1 - k, 1),
                      child:     child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: _alTocarTita,
                  child: RepaintBoundary(child: _buildCharacter()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openHelp() => showDialog(
    context: context,
    builder: (_) => const HelpDialog(),
  );

  Widget _buildCharacter() {
    final width  = _TitaSize.width(context);
    final height = width * _TitaSize.aspect;

    final hayErrores =
        widget.state == VampiritoState.error && widget.errores.isNotEmpty;

    return SizedBox(
      width:  width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _TitaImages.image(context, _expr)),
          // La notificación roja: cuántos errores hay.
          if (hayErrores) Positioned(top: 0, right: 0, child: _insignia()),
        ],
      ),
    );
  }

  // ── Globo de diálogo ──────────────────────────────────────────────────────

  Widget _buildBubble(double anchoMax) {
    final esError = widget.state == VampiritoState.error;
    final esLista = esError && widget.errores.length > 1;
    final c       = _bubbleContent();
    final size    = MediaQuery.sizeOf(context);

    const colaAncho = 12.0;
    final maxCuerpo = math.min(340.0, anchoMax - colaAncho);

    final cuerpo = Container(
      constraints: BoxConstraints(
        maxWidth: maxCuerpo,
        minWidth: math.min(130.0, maxCuerpo),
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppTheme.currentLine,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: c.color, width: AppTheme.borde),
      ),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: esLista ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
        children: esLista ? _hijosLista() : _hijosUnSolo(c, esError),
      ),
    );

    // La colita sale por el lado derecho (hacia Tita), 28 px sobre la base.
    final cola = Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Transform.translate(
        offset: const Offset(-2, 0),
        child: CustomPaint(
          size:    const Size(colaAncho, 24),
          painter: _ColaLateralPainter(fondo: AppTheme.currentLine, borde: c.color),
        ),
      ),
    );

    // Si no cabe (pantallas bajitas o con el teclado abierto), se desplaza.
    return Row(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height * 0.55),
            child: SingleChildScrollView(
              reverse: !esLista, // una lista se lee de arriba hacia abajo
              child:   cuerpo,
            ),
          ),
        ),
        cola,
      ],
    );
  }

  /// Un solo mensaje: la frase, la pista, el ejemplo (y, si es un error de
  /// sintaxis, el botón para ir a su línea).
  List<Widget> _hijosUnSolo(_BubbleContent c, bool esError) {
    final linea = esError && widget.errores.isNotEmpty
        ? widget.errores.first.linea
        : null;

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width:  24,
            height: 24,
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(c.icon, size: 14, color: c.color),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                c.text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.fuente(
                  fontSize:   13.5,
                  fontWeight: FontWeight.w700,
                  color:      AppTheme.foreground,
                  height:     1.3,
                ),
              ),
            ),
          ),
        ],
      ),
      if (c.tip != null) ...[
        const SizedBox(height: 10),
        _buildTip(c.tip!),
      ],
      if (c.exampleCode != null) ...[
        const SizedBox(height: 10),
        _buildExampleCard(c),
      ],
      if (linea != null) ...[
        const SizedBox(height: 10),
        _botonIrALinea(linea),
      ],
    ];
  }

  /// Varios errores: una lista; tocar uno lleva el cursor a esa línea.
  List<Widget> _hijosLista() {
    return [
      Row(
        children: [
          Container(
            width:  24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.red.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pest_control, size: 14, color: AppTheme.red),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.errores.length} cosas por revisar',
              style: AppTheme.fuente(
                fontSize:   14,
                fontWeight: FontWeight.w800,
                color:      AppTheme.foreground,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap:    _cerrarTarjeta,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 20, color: AppTheme.comment),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Toca una para ir a esa línea',
        style: AppTheme.fuente(
          fontSize:   11.5,
          fontWeight: FontWeight.w600,
          color:      AppTheme.comment,
        ),
      ),
      const SizedBox(height: 10),
      for (final e in widget.errores) _filaError(e),
    ];
  }

  /// Una fila de la lista: el número de línea, la frase y la pista.
  Widget _filaError(ErrorCodigo e) {
    final partes = _partirError(e.mensaje);
    final linea  = e.linea;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color:        AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: linea == null
              ? null
              : () {
                  widget.onIrALinea?.call(linea);
                  _cerrarTarjeta();
                },
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.selection, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width:   46,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color:        AppTheme.red.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'línea',
                        style: AppTheme.fuente(
                          fontSize:   9.5,
                          fontWeight: FontWeight.w700,
                          color:      AppTheme.red,
                        ),
                      ),
                      Text(
                        linea == null ? '!' : '$linea',
                        style: AppTheme.fuente(
                          fontSize:   17,
                          fontWeight: FontWeight.w900,
                          color:      AppTheme.red,
                          height:     1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partes.descripcion,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.fuente(
                          fontSize:   12.5,
                          fontWeight: FontWeight.w700,
                          color:      AppTheme.foreground,
                          height:     1.25,
                        ),
                      ),
                      if (partes.pista != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          partes.pista!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.fuente(
                            fontSize:   11.5,
                            fontWeight: FontWeight.w600,
                            color:      AppTheme.yellow,
                            height:     1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (linea != null)
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppTheme.comment),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// El botón azul del cuadro de un solo error: lleva el cursor a su línea.
  Widget _botonIrALinea(int linea) {
    final sombra = Color.lerp(AppTheme.cyan, Colors.black, 0.30)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          widget.onIrALinea?.call(linea);
          _cerrarTarjeta();
        },
        child: Container(
          padding:   const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:        AppTheme.cyan,
            borderRadius: BorderRadius.circular(12),
            boxShadow:    [BoxShadow(color: sombra, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.my_location_rounded,
                  size: 16, color: AppTheme.background),
              const SizedBox(width: 6),
              Text(
                'IR A LA LÍNEA $linea',
                style: AppTheme.fuente(
                  fontSize:      12.5,
                  fontWeight:    FontWeight.w900,
                  letterSpacing: 0.6,
                  color:         AppTheme.background,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La pista (👉): una cajita amarilla suave dentro del globo.
  Widget _buildTip(String tip) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color:        AppTheme.yellow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, size: 15, color: AppTheme.yellow),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tip,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.fuente(
                fontSize:   12.5,
                fontWeight: FontWeight.w700,
                color:      AppTheme.yellow,
                height:     1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// El cuadrito "así se escribe": un recuadro oscuro con el código de ejemplo.
  Widget _buildExampleCard(_BubbleContent c) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color:        AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.green.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 14, color: AppTheme.green),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  c.exampleTitle ?? 'Ejemplo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.fuente(
                    fontSize:   12,
                    fontWeight: FontWeight.w800,
                    color:      AppTheme.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            _codigoColoreado(c.exampleCode!),
            style: const TextStyle(
              fontFamily: AppTheme.familiaMono,
              fontSize:   11.5,
              height:     1.4,
              color:      AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }

  _BubbleContent _bubbleContent() {
    switch (widget.state) {
      case VampiritoState.error:
        final e = _partirError(
            widget.errores.isEmpty ? '' : widget.errores.first.mensaje);

        return _BubbleContent(
          text:  e.descripcion.length > 200
              ? '${e.descripcion.substring(0, 200)}...'
              : e.descripcion,
          tip:          e.pista,
          exampleTitle: e.ejemploTitulo,
          exampleCode:  e.ejemploCodigo,
          color: AppTheme.red,
          icon:  Icons.pest_control,
        );

      case VampiritoState.success:
        return const _BubbleContent(
          text:  '¡Compilación exitosa! 🌿✨\nYa puedes simularlo o enviarlo al robot.',
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

  /// Separa un mensaje de error en: descripción (❌), pista (👉) y ejemplo (📖).
  _ErrorPartes _partirError(String msg) {
    final lineas = msg.split('\n');
    final iEj    = lineas.indexWhere((l) => l.trimLeft().startsWith('📖'));
    final cuerpo = iEj >= 0 ? lineas.sublist(0, iEj) : lineas;

    String? ejTitulo;
    String? ejCodigo;
    if (iEj >= 0) {
      ejTitulo = lineas[iEj].replaceFirst('📖', '').trim();
      final codigo = lineas
          .sublist(iEj + 1)
          .map((l) => l.startsWith('   ') ? l.substring(3) : l)
          .join('\n')
          .trimRight();
      ejCodigo = codigo.isEmpty ? null : codigo;
    }

    final descripcion = cuerpo
        .where((l) => !l.trimLeft().startsWith('👉'))
        .map((l) => l.replaceAll('❌ ', '').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');

    return _ErrorPartes(
      descripcion:   descripcion,
      pista:         _tipFromError(cuerpo.join('\n')),
      ejemploTitulo: ejTitulo,
      ejemploCodigo: ejCodigo,
    );
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
      return 'Usa un número más pequeño en la variable del REPETIR.';
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
  final int?         commandCount; // cuántos comandos quedaron (solo si compiló)
  final VoidCallback onComplete;

  const VampiritoExecutionAnimation({
    super.key,
    required this.success,
    required this.onComplete,
    this.errorMessage,
    this.commandCount,
  });

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
  late final AnimationController _shakeCtrl;
  late final AnimationController _flyOutCtrl;
  late final AnimationController _bannerCtrl;
  late final Animation<double>   _bannerPop; // aparece con un "rebotito"
  late final AnimationController _boingCtrl;  // el "boing" leve de Tita
  late final Animation<double>   _flyIn;
  late final Animation<double>   _flyOut;

  /// Cuánto se aplasta Tita: baja hasta un 8 % de su alto y vuelve a 0.
  double get _boingK => math.sin(_boingCtrl.value * math.pi) * 0.08;

  _Expression _expr       = _Expression.excited;
  bool        _showBubble = false;
  bool        _isSuspense = false;

  // La compilación real es instantánea: esto es solo el "suspenso" de Tita.
  // Se puede saltar tocando la pantalla.
  static const _suspenseMs = 1200;

  bool _resultShown = false; // ya se mostró el resultado
  bool _closing     = false; // ya se está cerrando
  int  _gen         = 0;     // cambia al saltar: invalida la secuencia de suspenso

  static const _mensajesExito = [
    '¡Excelente! Tu programa compiló sin errores.',
    '¡Lo lograste! Todo salió perfecto.',
    '¡Muy bien! Tu robot ya sabe qué hacer.',
    '¡Increíble! Cero errores.',
  ];
  late final String _mensajeExito =
      _mensajesExito[math.Random().nextInt(_mensajesExito.length)];

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

    _shakeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 550),
    );

    _flyOutCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _flyIn  = CurvedAnimation(parent: _flyInCtrl,  curve: Curves.easeOutBack);
    _flyOut = CurvedAnimation(parent: _flyOutCtrl, curve: Curves.easeInBack);

    _bannerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 420),
    );
    _bannerPop = CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutBack);
    _boingCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 450),
    );

    _runSequence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Normalmente ya están en caché (la mascota las precarga); esto cubre el
    // caso de mostrar la animación sin la mascota en pantalla.
    _TitaImages.precacheAll(context);
  }

  Future<void> _runSequence() async {
    final gen = _gen;

    // Cada `await` puede terminar cuando el overlay ya se quitó, o cuando el
    // usuario saltó la animación (_gen cambió): en ambos casos se abandona.
    await _flyInCtrl.forward();
    if (!mounted || gen != _gen) return;

    setState(() {
      _isSuspense = true;
      _expr       = _Expression.excited;
    });
    _boingCtrl.forward(from: 0);
    _suspenseCtrl.repeat(reverse: true);
    _sparkleCtrl.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: _suspenseMs));
    if (!mounted || gen != _gen) return;

    await _showResult();
  }

  /// Un toque: si todavía está en el suspenso, salta al resultado de una vez;
  /// si el resultado ya se ve, lo cierra (y Tita se va).
  void _onTap() {
    if (_closing || !mounted) return;
    if (!_resultShown) {
      _gen++;                 // cancela el suspenso
      _flyInCtrl.value = 1.0; // Tita llega al centro de una vez
      _showResult();
    } else {
      _cerrar();
    }
  }

  Future<void> _showResult() async {
    if (_resultShown || !mounted) return;
    _resultShown = true;

    _suspenseCtrl.stop();
    _sparkleCtrl.stop();
    setState(() {
      _isSuspense = false;
      _expr       = widget.success ? _Expression.happy : _Expression.confused;
      _showBubble = true;
    });
    _bannerCtrl.forward();
    _boingCtrl.forward(from: 0); // cambia de cara y habla: ¡boing!

    // El resultado NO se cierra solo: se queda con calma hasta que la persona
    // toque la pantalla o el botón (CONTINUAR / ENTENDIDO).
    if (widget.success) {
      _reactionCtrl.forward();
    } else {
      _shakeCtrl.forward();
    }
  }

  Future<void> _cerrar() async {
    if (_closing || !mounted) return;
    _closing = true;

    await _bannerCtrl.reverse();
    if (!mounted) return;
    setState(() => _showBubble = false);

    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    await _flyOutCtrl.forward();
    if (!mounted) return;

    widget.onComplete();
  }

  @override
  void dispose() {
    _boingCtrl.dispose();
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

  List<Widget> _buildSparkles(double charW, double charH) {
    // Los offsets están pensados para una caja de ~54 px de semi-ancho; se
    // escalan para que las chispas rodeen a Tita sea cual sea su tamaño.
    final k = charW / 54;
    return List.generate(_sparkleOffsets.length, (i) {
      final phase   = i / _sparkleOffsets.length;
      final rawT    = (_sparkleCtrl.value + phase) % 1.0;
      final opacity = math.sin(rawT * math.pi).clamp(0.0, 1.0);
      final size    = 4.0 + opacity * 4.0;
      final off     = _sparkleOffsets[i];
      final color   = _sparkleColors[i];

      // La transparencia va en los colores y no en un Opacity: así no se crea
      // una capa aparte por cada chispa en cada fotograma.
      return Positioned(
        left: charW / 2 + off.dx * k - size / 2,
        top:  charH / 2 + off.dy * k - size / 2,
        child: Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            color:     color.withValues(alpha: opacity),
            shape:     BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      color.withValues(alpha: 0.7 * opacity),
                blurRadius: size * 1.5,
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Sin un Material detrás, todo el texto de una capa flotante (Overlay) sale
    // con un subrayado amarillo doble.
    return Material(
      type:  MaterialType.transparency,
      child: _construir(context),
    );
  }

  Widget _construir(BuildContext context) {
    final size    = MediaQuery.sizeOf(context);
    final charW   = _TitaSize.width(context);
    final charH   = charW * _TitaSize.aspect;
    final maxScale = math.min(
      (size.width * 0.72) / charW,
      (size.height * 0.36) / charH,
    ).clamp(1.0, _TitaSize.maxExecScale);

    final navBottom = MediaQuery.viewPaddingOf(context).bottom;
    final startX  = size.width  - charW - 16;
    final startY  = size.height - charH - navBottom - 16;
    final centerX = size.width  / 2 - charW / 2;
    final centerY = size.height / 2 - charH / 2;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _flyInCtrl, _suspenseCtrl, _sparkleCtrl,
        _reactionCtrl, _shakeCtrl, _flyOutCtrl, _bannerCtrl, _boingCtrl,
      ]),
      builder: (context, _) {
        double t, x, y, scale;

        if (!_flyOutCtrl.isAnimating && _flyOutCtrl.value == 0) {
          t     = _flyIn.value;
          x     = lerpDouble(startX, centerX, t)!;
          y     = lerpDouble(startY, centerY, t)!;
          scale = lerpDouble(1.0, maxScale, t)!;
        } else {
          t     = _flyOut.value;
          x     = lerpDouble(centerX, startX, t)!;
          y     = lerpDouble(centerY, startY, t)!;
          scale = lerpDouble(maxScale, 1.0, t)!;
        }

        final bounceOffset = _reactionCtrl.isAnimating ? _bounce.value : 0.0;
        final shakeOffset  = _shakeCtrl.isAnimating    ? _shakeX       : 0.0;
        final trembleX     = _suspenseTrembleX;
        final trembleY     = _suspenseTrembleY;

        final compact = size.height < 700;
        final safeTop = MediaQuery.viewPaddingOf(context).top;

        return Stack(
          children: [

            // ── Fondo: oscurece y recibe los toques (saltar / continuar) ──
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap:    _onTap,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: _flyInCtrl.value * 0.55),
                ),
              ),
            ),

            // ── Burbuja de Tita (arriba) ────────────────────────────────
            if (_showBubble)
              Positioned(
                top:   safeTop + 14,
                left:  20,
                right: 20,
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _bannerCtrl,
                    child: ScaleTransition(
                      scale:     _bannerPop,
                      alignment: Alignment.bottomCenter,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width:   double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                decoration: BoxDecoration(
                                  color:        Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFE5E5E5), width: 2),
                                ),
                                child: Text(
                                  widget.success
                                      ? _mensajeExito
                                      : _cleanErrorText(widget.errorMessage),
                                  textAlign: TextAlign.center,
                                  maxLines:  4,
                                  overflow:  TextOverflow.ellipsis,
                                  style: AppTheme.fuente(
                                    fontSize:   15,
                                    fontWeight: FontWeight.w600,
                                    color:      const Color(0xFF4B4B4B),
                                    height:     1.35,
                                  ),
                                ),
                              ),
                              // colita: tapa el borde de la burbuja y apunta a Tita
                              Transform.translate(
                                offset: const Offset(0, -1.5),
                                child: const CustomPaint(
                                  size:    Size(24, 12),
                                  painter: _ColaBurbujaPainter(),
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

            // ── Número grande + botón (abajo) ───────────────────────────
            if (_showBubble)
              Positioned(
                left:   24,
                right:  24,
                bottom: navBottom + 20,
                child: FadeTransition(
                  opacity: _bannerCtrl,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end:   Offset.zero,
                    ).animate(_bannerPop),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IgnorePointer(child: _bloqueNumero(compact)),
                            SizedBox(height: compact ? 12 : 20),
                            _BotonDuo(
                              texto: widget.success ? 'CONTINUAR' : 'ENTENDIDO',
                              color: widget.success
                                  ? AppTheme.green
                                  : AppTheme.orange,
                              onTap: _cerrar,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Pista para saltar el suspenso ───────────────────────────
            if (_isSuspense)
              Positioned(
                left:   0,
                right:  0,
                bottom: navBottom + 28,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      'Toca para saltar',
                      style: AppTheme.fuente(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),

            // ── TITA + lucecitas ───────────────────────────────────────
            Positioned(
              left: x + shakeOffset + trembleX,
              top:  y + bounceOffset + trembleY,
              child: Transform.scale(
                scale: scale,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(1, 1 - _boingK, 1),
                  child: SizedBox(
                    width:  charW,
                    height: charH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: _TitaImages.image(context, _expr)),
                        if (_isSuspense) ..._buildSparkles(charW, charH),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          ],
        );
      },
    );
  }

  /// Línea del error (si el mensaje la trae): "en la línea 3 ..." → 3
  int? _lineaDelError() {
    final m = RegExp(r'[Ll]ínea\s+(\d+)').firstMatch(widget.errorMessage ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Como el "1 día de racha": un número grande y una etiqueta.
  ///  · compiló  → cuántos comandos quedaron
  ///  · error    → en qué línea hay que mirar
  Widget _bloqueNumero(bool compact) {
    final color  = widget.success ? AppTheme.green : AppTheme.orange;
    final numero = widget.success ? widget.commandCount : _lineaDelError();
    final String? etiqueta = numero == null
        ? null
        : widget.success
            ? (numero == 1 ? 'comando listo' : 'comandos listos')
            : 'línea por revisar';

    final grande = AppTheme.fuente(
      fontSize:   compact ? 56 : 76,
      fontWeight: FontWeight.w800,
      color:      color,
      height:     1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (numero != null)
          TweenAnimationBuilder<double>(
            tween:    Tween<double>(begin: 0, end: numero.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve:    Curves.easeOut,
            builder:  (_, v, __) => Text('${v.round()}', style: grande),
          )
        else
          Text(widget.success ? '¡Listo!' : '¡Ups!', style: grande),
        if (etiqueta != null) ...[
          const SizedBox(height: 4),
          Text(
            etiqueta,
            style: AppTheme.fuente(
              fontSize:   compact ? 17 : 20,
              fontWeight: FontWeight.w700,
              color:      color,
            ),
          ),
        ],
      ],
    );
  }

  String _cleanErrorText(String? msg) {
    if (msg == null || msg.isEmpty) {
      return '¡Ups! Hay algo por revisar en tu código.';
    }
    final firstLine = msg
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => msg)
        .replaceAll('❌ ', '')
        .trim();
    return firstLine.length > 140 ? '${firstLine.substring(0, 140)}…' : firstLine;
  }
}

/// Botón grande con "borde de abajo", que se hunde al apretarlo.
class _BotonDuo extends StatefulWidget {
  final String       texto;
  final Color        color;
  final VoidCallback onTap;
  const _BotonDuo({
    required this.texto,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BotonDuo> createState() => _BotonDuoState();
}

class _BotonDuoState extends State<_BotonDuo> {
  bool _apretado = false;

  @override
  Widget build(BuildContext context) {
    final sombra = Color.lerp(widget.color, Colors.black, 0.30)!;
    return SizedBox(
      height: 56,
      child: GestureDetector(
        behavior:    HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _apretado = true),
        onTapCancel: () => setState(() => _apretado = false),
        onTapUp: (_) {
          setState(() => _apretado = false);
          widget.onTap();
        },
        child: AnimatedContainer(
          duration:  const Duration(milliseconds: 80),
          height:    52,
          width:     double.infinity,
          transform: Matrix4.translationValues(0, _apretado ? 4 : 0, 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:        widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _apretado
                ? const []
                : [BoxShadow(color: sombra, offset: const Offset(0, 4))],
          ),
          child: Text(
            widget.texto,
            style: AppTheme.fuente(
              fontSize:      16,
              fontWeight:    FontWeight.w800,
              letterSpacing: 1.0,
              color:         AppTheme.background,
            ),
          ),
        ),
      ),
    );
  }
}

/// Colita de la burbuja blanca (apunta hacia abajo, a Tita).
class _ColaBurbujaPainter extends CustomPainter {
  const _ColaBurbujaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(relleno, Paint()..color = Colors.white);

    final lados = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      lados,
      Paint()
        ..color       = const Color(0xFFE5E5E5)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ColaBurbujaPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINTER — Colita del globo de Tita (sale de lado, apuntando a su cabeza)
// ═══════════════════════════════════════════════════════════════════════════

class _ColaLateralPainter extends CustomPainter {
  final Color fondo;
  final Color borde;
  const _ColaLateralPainter({required this.fondo, required this.borde});

  @override
  void paint(Canvas canvas, Size size) {
    // El relleno tapa el borde del globo en la unión, para que parezcan una sola pieza.
    final relleno = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(relleno, Paint()..color = fondo);

    // El borde va solo en los dos lados inclinados.
    final lados = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);
    canvas.drawPath(
      lados,
      Paint()
        ..color       = borde
        ..style       = PaintingStyle.stroke
        ..strokeWidth = AppTheme.borde
        ..strokeJoin  = StrokeJoin.round
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ColaLateralPainter old) =>
      old.fondo != fondo || old.borde != borde;
}
