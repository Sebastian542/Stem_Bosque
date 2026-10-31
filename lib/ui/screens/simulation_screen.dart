import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/confetti_widget.dart';
import '../widgets/duo_button.dart';

// ══════════════════════════════════════════════════════════════
//  SimulationScreen
//  Recibe la lista de comandos compilados (GIRAR X / AVANZAR X)
//  y anima un robot sobre un canvas con cuadrícula.
// ══════════════════════════════════════════════════════════════

class SimulationScreen extends StatefulWidget {
  /// Lista de líneas compiladas, p.ej. ["AVANZAR 5", "GIRAR -3", ...]
  final List<String> commands;

  const SimulationScreen({super.key, required this.commands});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen>
    with TickerProviderStateMixin {

  // ── Estado del robot ───────────────────────────────────────
  double _x = 0;
  double _y = 0;
  double _angle = 0; // radianes

  // ── Obstáculos y Edición ──────────────────────────────────
  final List<Rect> _obstacles = [];
  bool _isEditMode = false;
  bool _collisionDetected = false;

  // ── Rastro (trail) ─────────────────────────────────────────
  final List<Offset> _trail = [];
  double _distance = 0; // cm recorridos (solo AVANZAR, sin importar el sentido)

  // ── Comandos tal como los ve el niño (tarjetas y globo de Tita) ──
  late final List<_Cmd> _cmds;
  final ScrollController _chipsCtrl = ScrollController();
  int _chipScrollIndex = -1; // último comando al que se desplazó la tira
  static const double _chipW   = 92;
  static const double _chipGap = 8;

  OverlayEntry? _confeti; // confeti al terminar

  // ── Control de animación ───────────────────────────────────
  bool   _isPlaying  = false;
  bool   _isDone     = false;
  int    _cmdIndex   = 0;       // comando actual
  double _remaining  = 0;       // lo que falta del comando actual (grados o cm, en valor absoluto)
  int    _stepSign   = 1;       // dirección (+1 / -1)

  // Comando en curso (para reanudar tras una pausa sin repetirlo desde cero).
  bool Function(double amount)? _activeStep;
  double _activeStepSize = 0;

  // Se incrementa al reproducir, pausar o reiniciar: invalida los temporizadores
  // pendientes para que nunca haya dos cadenas de animación a la vez.
  int _runToken = 0;

  // ── Plano desplazable ──────────────────────────────────────
  // El robot vive en un plano enorme (2400 cm hacia cada lado desde el inicio)
  // que se puede arrastrar y acercar/alejar con los dedos: si el robot sale de
  // la pantalla, basta con desplazarse para seguirlo.
  static const double _worldSize = 12000.0;
  final TransformationController _tc = TransformationController();
  Size _viewSize   = Size.zero; // tamaño visible del lienzo
  bool _vistaPedida = false;    // ya se pidió centrar la vista inicial
  bool _vistaLista  = false;    // la vista inicial ya está centrada

  // ── Unidades del lenguaje ──────────────────────────────────
  //   GIRAR n   → n GRADOS (positivo = derecha, sentido horario en pantalla)
  //   AVANZAR n → n CENTÍMETROS (negativo = hacia atrás)
  static const double _pxPerCm    = 5.0;  // escala del canvas: 1 cm = 5 px
  /// Cada orden se anima en pocos cuadros, no uno por centímetro o grado.
  static const int _maxFrames = 12;
  static const int _stepMs = 16;

  /// Avisa solo al canvas y a los números, sin reconstruir botones ni tarjetas.
  final ValueNotifier<int> _pose = ValueNotifier<int>(0);

  // ─────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // El robot empieza en el centro; se calcula en el primer build
    _cmds = widget.commands.map(_Cmd.parse).toList();
  }

  @override
  void dispose() {
    _runToken++; // cancela cualquier temporizador pendiente
    _confeti?.remove();
    _chipsCtrl.dispose();
    _pose.dispose();
    _tc.dispose();
    super.dispose();
  }

  /// El robot empieza en el centro del plano.
  void _initRobot() {
    if (_trail.isEmpty) {
      _x = _worldSize / 2;
      _y = _worldSize / 2;
      _trail.add(Offset(_x, _y));
    }
  }

  /// Mueve la vista para que el robot quede en el centro de la pantalla
  /// (conserva el zoom actual).
  void _centrarEnRobot() {
    if (_viewSize.isEmpty) return;
    final s  = _tc.value.getMaxScaleOnAxis();
    final tx = _viewSize.width  / 2 - _x * s;
    final ty = _viewSize.height / 2 - _y * s;
    // Matriz de escala s + traslación (tx, ty)
    _tc.value = Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  // ─────────────────────────────────────────────────────────
  // LÓGICA DE SIMULACIÓN
  // ─────────────────────────────────────────────────────────

  void _play() {
    if (_isPlaying || _isDone) return;
    _runToken++;
    setState(() => _isPlaying = true);
    if (_activeStep != null && _remaining > 1e-9) {
      // Reanuda el comando que quedó a medias.
      _animateSteps(_activeStep!, _activeStepSize);
    } else {
      _runNextCommand();
    }
  }

  void _pause() {
    _runToken++;
    setState(() => _isPlaying = false);
  }

  void _reset() {
    _runToken++;
    setState(() {
      _isPlaying  = false;
      _isDone     = false;
      _collisionDetected = false;
      _cmdIndex   = 0;
      _remaining  = 0;
      _activeStep = null;
      _angle      = 0;
      _distance   = 0;
      _trail.clear();
      // El robot vuelve al centro del plano en el próximo build
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centrarEnRobot();
    });
  }

  void _runNextCommand() {
    if (!_isPlaying) return;

    if (_cmdIndex >= widget.commands.length) {
      setState(() { _isPlaying = false; _isDone = true; });
      _celebrar();
      return;
    }

    final line  = widget.commands[_cmdIndex].trim();
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 2) { _cmdIndex++; _runNextCommand(); return; }

    final cmd = parts[0];
    final val = double.tryParse(parts[1]) ?? 0;
    _stepSign  = val >= 0 ? 1 : -1;
    _remaining = val.abs();

    final paso = _pasoDe(_remaining);
    if (cmd == 'AVANZAR') {
      _activeStep     = _stepAvanzar;
      _activeStepSize = paso;
      setState(() {});
      _animateSteps(_stepAvanzar, paso);
    } else if (cmd == 'GIRAR') {
      _activeStep     = _stepGirar;
      _activeStepSize = paso;
      setState(() {});
      _animateSteps(_stepGirar, paso);
    } else {
      _cmdIndex++;
      _runNextCommand();
    }
  }

  /// Avanza la animación del comando actual de a `stepSize` unidades por cuadro.
  /// El último cuadro usa lo que reste, así que `GIRAR 90` gira exactamente 90°
  /// y `AVANZAR 2.5` recorre exactamente 2.5 cm (sin truncar decimales).
  void _animateSteps(bool Function(double amount) stepFn, double stepSize) {
    if (!_isPlaying || !mounted) return;
    if (_remaining <= 1e-9) {
      _activeStep = null;
      _cmdIndex++;
      Future.delayed(Duration.zero, _runNextCommand);
      return;
    }

    final amount = min(stepSize, _remaining);
    if (!stepFn(amount)) return; // bloqueado (colisión): queda en pausa sin gastar el comando
    _remaining -= amount;

    final token = _runToken;
    Future.delayed(const Duration(milliseconds: _stepMs), () {
      if (token == _runToken) _animateSteps(stepFn, stepSize);
    });
  }

  /// Parte el movimiento en como mucho [_maxFrames] cuadros.
  double _pasoDe(double total) {
    if (total <= 0) return total;
    final frames = min(_maxFrames, max(1, total.ceil()));
    return total / frames;
  }

  void _refrescarRobot() {
    _pose.value++;
  }

  bool _stepAvanzar(double cm) {
    if (!mounted) return false;

    final px    = _stepSign * cm * _pxPerCm;
    final nextX = _x + px * cos(_angle);
    final nextY = _y + px * sin(_angle);

    // Detección de colisión básica
    // El robot mide aprox 40x30, usaremos un radio de seguridad
    final robotRect = Rect.fromCenter(center: Offset(nextX, nextY), width: 34, height: 34);
    bool hit = false;
    for (var obs in _obstacles) {
      if (obs.overlaps(robotRect)) {
        hit = true;
        break;
      }
    }

    if (hit) {
      setState(() {
        _collisionDetected = true;
        _isPlaying = false;
      });
      return false;
    }

    _x = nextX;
    _y = nextY;
    _distance += cm;
    _trail.add(Offset(_x, _y));
    _refrescarRobot();
    return true;
  }

  void _addObstacle(Offset pos) {
    // Alinear a los cuadros del plano (cada cuadro = 10 cm = 50 px)
    const lado = 10 * _pxPerCm;
    final gx = (pos.dx / lado).floor() * lado;
    final gy = (pos.dy / lado).floor() * lado;
    final newObs = Rect.fromLTWH(gx, gy, lado, lado);

    setState(() {
      // Si ya existe uno ahí, lo quitamos (toggle)
      if (_obstacles.contains(newObs)) {
        _obstacles.remove(newObs);
      } else {
        _obstacles.add(newObs);
      }
    });
  }

  bool _stepGirar(double grados) {
    if (!mounted) return false;
    _angle += _stepSign * grados * pi / 180;
    _refrescarRobot();
    return true;
  }

  // ─────────────────────────────────────────────────────────
  // AYUDANTES VISUALES
  // ─────────────────────────────────────────────────────────

  /// 20.0 → "20", 2.5 → "2.5", -0.00001 → "0" (sin ruido de decimales).
  String _fmt(double v) {
    final r = double.parse(v.toStringAsFixed(1));
    if (r == 0) return '0';
    return r == r.truncateToDouble() ? r.toInt().toString() : r.toString();
  }

  /// Qué cara pone Tita y qué dice, según lo que esté pasando.
  (String, String) _guia() {
    if (_isEditMode && !_isPlaying) {
      return ('watching', 'Modo bloques: toca el plano para poner o quitar obstáculos.');
    }
    if (_collisionDetected) {
      return ('confused', '¡Ups! Chocó con un obstáculo. Toca reiniciar para intentarlo de nuevo.');
    }
    if (_isDone) {
      return ('happy', '¡Lo lograste! Recorrió ${_fmt(_distance)} cm.');
    }
    if (_isPlaying && _cmds.isNotEmpty) {
      final c = _cmds[_cmdIndex.clamp(0, _cmds.length - 1).toInt()];
      final v = _fmt(c.valor.abs());
      if (c.esAvanzar) {
        return ('excited', c.valor >= 0 ? 'Avanzando $v cm' : 'Retrocediendo $v cm');
      }
      if (c.esGirar) {
        return ('excited',
            c.valor >= 0 ? 'Girando $v° a la derecha' : 'Girando $v° a la izquierda');
      }
    }
    if (_cmdIndex == 0) {
      return ('watching', '¡Vamos a ver tu programa! Toca REPRODUCIR.');
    }
    return ('neutral', 'En pausa. Toca REPRODUCIR para seguir.');
  }

  /// Confeti al terminar la simulación (el mismo que usa el IDE al compilar bien).
  void _celebrar() {
    if (!mounted) return;
    _confeti?.remove();
    final entry = OverlayEntry(builder: (_) => const ConfettiWidget());
    _confeti = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (_confeti == entry) {
        entry.remove();
        _confeti = null;
      }
    });
  }

  /// Vuelve al inicio y reproduce de nuevo.
  void _otraVez() {
    _reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _play();
    });
  }

  /// Chips con la posición, el giro y la distancia (para que miren los números).
  Widget _estadisticas() {
    final xCm = (_x - _worldSize / 2) / _pxPerCm;
    final yCm = -(_y - _worldSize / 2) / _pxPerCm; // en el plano, +y es hacia arriba
    var g = (_angle * 180 / pi) % 360;
    if (g > 180) g -= 360;

    Widget chip(IconData icono, Color color, String texto) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.background.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.selection, width: AppTheme.borde),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              texto,
              style: AppTheme.fuente(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.foreground,
              ),
            ),
          ],
        ),
      );
    }

    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: IgnorePointer(
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            chip(Icons.place_rounded, AppTheme.cyan,
                '(${_fmt(xCm)}, ${_fmt(yCm)})'),
            chip(Icons.explore_rounded, AppTheme.orange, '${_fmt(g)}°'),
            chip(Icons.straighten_rounded, AppTheme.green,
                '${_fmt(_distance)} cm'),
          ],
        ),
      ),
    );
  }

  /// Tita acompañando abajo a la izquierda, con su globo.
  Widget _guiaTita() {
    final (img, texto) = _guia();
    return Positioned(
      left: 8,
      bottom: 8,
      right: 74,
      child: IgnorePointer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Image.asset(
                'assets/images/tita_$img.png',
                key: ValueKey(img),
                height: 92,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: _BurbujaMini(texto: texto),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta de un comando: gris (falta), azul (ahora) o verde (listo).
  Widget _chipComando(int i) {
    final c = _cmds[i];
    final hecho  = _isDone || i < _cmdIndex;
    final actual = !_isDone && i == _cmdIndex;
    final color  = hecho
        ? AppTheme.green
        : actual
            ? AppTheme.cyan
            : AppTheme.comment;
    final IconData icono = c.esAvanzar
        ? (c.valor >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
        : (c.valor >= 0 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded);
    final texto = c.esAvanzar
        ? '${_fmt(c.valor.abs())} cm'
        : '${_fmt(c.valor.abs())}°';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _chipW,
      margin: const EdgeInsets.only(right: _chipGap),
      decoration: BoxDecoration(
        color: (hecho || actual) ? color.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: actual
              ? color
              : hecho
                  ? color.withValues(alpha: 0.5)
                  : AppTheme.selection,
          width: AppTheme.borde,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            texto,
            style: AppTheme.fuente(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Simulación'),
        actions: [
          // Botón Modo Edición
          IconButton(
            icon: Icon(_isEditMode ? Icons.layers : Icons.layers_outlined),
            color: _isEditMode ? AppTheme.orange : AppTheme.comment,
            tooltip: 'Modo Bloque (Editar obstáculos)',
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
          ),
          // Info de comandos
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                widget.commands.length == 1
                    ? '1 comando'
                    : '${widget.commands.length} comandos',
                style: AppTheme.fuente(
                  color: AppTheme.comment,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Canvas del robot ─────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final view = Size(constraints.maxWidth, constraints.maxHeight);
                _viewSize = view;
                _initRobot();

                // Primera vez: centrar la vista en el robot (después del build).
                if (!_vistaPedida) {
                  _vistaPedida = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _centrarEnRobot();
                    setState(() => _vistaLista = true);
                  });
                }

                // El robot tiene un tamaño fijo en el plano (el zoom lo agranda).
                const robotScale = 1.0;

                return ClipRect(
                  child: Stack(
                    children: [
                      // Plano: se arrastra con un dedo y se acerca con dos.
                      Opacity(
                        opacity: _vistaLista ? 1 : 0,
                        child: InteractiveViewer(
                          transformationController: _tc,
                          constrained: false,
                          minScale: 0.3,
                          maxScale: 3.0,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          child: SizedBox(
                            width:  _worldSize,
                            height: _worldSize,
                            child: GestureDetector(
                              onTapUp: _isEditMode
                                  ? (details) => _addObstacle(details.localPosition)
                                  : null,
                              child: Stack(
                                children: [
                                  // Cuadrícula: no cambia, se dibuja una sola vez.
                                  const RepaintBoundary(
                                    child: CustomPaint(
                                      size: Size(_worldSize, _worldSize),
                                      painter: _GridPainter(_worldSize, _pxPerCm),
                                    ),
                                  ),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _pose,
                                    builder: (_, __, ___) => CustomPaint(
                                      size: const Size(_worldSize, _worldSize),
                                      painter: _RobotPainter(
                                        robotX: _x,
                                        robotY: _y,
                                        angle: _angle,
                                        trail: _trail,
                                        obstacles: _obstacles,
                                        collision: _collisionDetected,
                                        robotScale: robotScale,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      ValueListenableBuilder<int>(
                        valueListenable: _pose,
                        builder: (_, __, ___) => _estadisticas(),
                      ),

                      // Tita acompaña y cuenta qué está haciendo el robot
                      _guiaTita(),

                      // Volver al robot
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: DuoIconButton(
                          icon: Icons.my_location_rounded,
                          color: AppTheme.cyan,
                          tooltip: 'Centrar en el robot',
                          onPressed: _centrarEnRobot,
                          fondo: AppTheme.background,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Panel de controles ───────────────────────────
          _buildControlPanel(),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    // Mantiene a la vista la tarjeta del comando que se está ejecutando.
    if (_cmdIndex != _chipScrollIndex) {
      _chipScrollIndex = _cmdIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_chipsCtrl.hasClients) return;
        final objetivo = (_cmdIndex * (_chipW + _chipGap) - 40)
            .clamp(0.0, _chipsCtrl.position.maxScrollExtent)
            .toDouble();
        _chipsCtrl.animateTo(
          objetivo,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }

    final r = context.responsive;
    final corto = r.isLandscapePhone || r.height < 520;
    final progreso = widget.commands.isEmpty
        ? 0.0
        : (_cmdIndex / widget.commands.length).clamp(0.0, 1.0).toDouble();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: AppTheme.currentLine, width: AppTheme.borde),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            r.horizontalPadding,
            corto ? 6 : 12,
            r.horizontalPadding,
            corto ? 8 : 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progreso),
                duration: const Duration(milliseconds: 300),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  backgroundColor: AppTheme.selection,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
                  minHeight: corto ? 6 : 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              if (!corto) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: r.isCompact ? 52 : 62,
                  child: ListView.builder(
                    controller: _chipsCtrl,
                    scrollDirection: Axis.horizontal,
                    itemCount: _cmds.length,
                    itemBuilder: (_, i) => _chipComando(i),
                  ),
                ),
              ],
              SizedBox(height: corto ? 8 : 12),

              Row(
                children: [
                  DuoIconButton(
                    icon: Icons.replay_rounded,
                    color: AppTheme.orange,
                    tooltip: 'Reiniciar',
                    onPressed: _reset,
                    size: corto ? 40 : 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DuoButton(
                      label: _isDone
                          ? 'OTRA VEZ'
                          : _isPlaying
                              ? 'PAUSAR'
                              : 'REPRODUCIR',
                      icon: _isDone
                          ? Icons.replay_rounded
                          : _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                      color: _isDone
                          ? AppTheme.cyan
                          : _isPlaying
                              ? AppTheme.orange
                              : AppTheme.green,
                      onPressed: _isDone ? _otraVez : (_isPlaying ? _pause : _play),
                      height: corto ? 40 : 46,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  CustomPainter del robot
// ══════════════════════════════════════════════════════════════

/// El plano cartesiano: cuadros de 10 cm, ejes X e Y que se cruzan en el punto
/// de inicio del robot (0, 0), y números cada 20 cm. En el plano, +x va a la
/// derecha y +y hacia arriba (el robot arranca mirando hacia +x).
class _GridPainter extends CustomPainter {
  final double world;
  final double pxPerCm;
  const _GridPainter(this.world, this.pxPerCm);

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppTheme.background,
    );

    final c      = world / 2;     // el origen (0, 0)
    final cuadro = pxPerCm * 10;  // 1 cuadro = 10 cm

    // Cuadrícula: más marcada cada 50 cm
    final fina   = Paint()..color = AppTheme.currentLine..strokeWidth = 1;
    final gruesa = Paint()
      ..color = AppTheme.selection.withAlpha(120)
      ..strokeWidth = 1.2;
    var k = 0;
    for (double x = 0; x <= size.width; x += cuadro, k++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), k % 5 == 0 ? gruesa : fina);
    }
    k = 0;
    for (double y = 0; y <= size.height; y += cuadro, k++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), k % 5 == 0 ? gruesa : fina);
    }

    // Ejes
    final eje = Paint()
      ..color = AppTheme.comment
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, c), Offset(size.width, c), eje);
    canvas.drawLine(Offset(c, 0), Offset(c, size.height), eje);

    // Marcas y números (cada 10 cm una marca, cada 20 cm un número)
    const estilo = TextStyle(
      color: AppTheme.comment,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );
    void texto(String t, Offset p, {double ax = 0, double ay = 0, TextStyle st = estilo}) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: st),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width * ax, p.dy - tp.height * ay));
    }

    final marca = Paint()
      ..color = AppTheme.comment
      ..strokeWidth = 1.8;
    for (int v = -600; v <= 600; v += 10) {
      if (v == 0) continue;
      final d = v * pxPerCm;
      final largo = v % 50 == 0 ? 8.0 : 5.0;
      canvas.drawLine(Offset(c + d, c - largo), Offset(c + d, c + largo), marca);
      canvas.drawLine(Offset(c - largo, c - d), Offset(c + largo, c - d), marca);
      if (v % 20 == 0) {
        texto('$v', Offset(c + d, c + 11), ax: 0.5);          // debajo del eje X
        texto('$v', Offset(c - 11, c - d), ax: 1, ay: 0.5);   // a la izquierda del eje Y
      }
    }

    // Nombres de los ejes
    const nombre = TextStyle(
      color: AppTheme.cyan,
      fontSize: 14,
      fontWeight: FontWeight.w900,
    );
    texto('X', Offset(c + 30 * pxPerCm, c - 10), ax: 0.5, ay: 1, st: nombre);
    texto('Y', Offset(c + 12, c - 30 * pxPerCm), ay: 0.5, st: nombre);

    // El punto de inicio
    canvas.drawCircle(
      Offset(c, c),
      10,
      Paint()
        ..color = AppTheme.green.withAlpha(170)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    texto(
      'inicio',
      Offset(c + 26, c + 16),
      st: const TextStyle(
        color: AppTheme.green,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.world != world || old.pxPerCm != pxPerCm;
}

class _RobotPainter extends CustomPainter {
  final double robotX;
  final double robotY;
  final double angle;
  final List<Offset> trail;
  final List<Rect> obstacles;
  final bool collision;
  final double robotScale;

  const _RobotPainter({
    required this.robotX,
    required this.robotY,
    required this.angle,
    required this.trail,
    required this.robotScale,
    this.obstacles = const [],
    this.collision = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Obstáculos
    _drawObstacles(canvas);

    // Rastro
    _drawTrail(canvas);

    // Robot
    _drawRobot(canvas);
  }

  void _drawObstacles(Canvas canvas) {
    final relleno = Paint()
      ..color = AppTheme.red.withAlpha(190)
      ..style = PaintingStyle.fill;
    final borde = Paint()
      ..color = AppTheme.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (var obs in obstacles) {
      final r = RRect.fromRectAndRadius(obs.deflate(2), const Radius.circular(8));
      canvas.drawRRect(r, relleno);
      canvas.drawRRect(r, borde);
    }
  }

  void _drawTrail(Canvas canvas) {
    if (trail.length < 2) return;
    final paint = Paint()
      ..color = AppTheme.green.withAlpha(150)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(trail.first.dx, trail.first.dy);
    for (int i = 1; i < trail.length; i++) {
      path.lineTo(trail[i].dx, trail[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  /// Un carrito visto desde arriba, como el real: ruedas amarillas, parabrisas
  /// y luces adelante (el frente es hacia +x).
  void _drawRobot(Canvas canvas) {
    canvas.save();
    canvas.translate(robotX, robotY);
    canvas.scale(robotScale);
    canvas.rotate(angle);

    final color  = collision ? AppTheme.red : AppTheme.cyan;
    final oscuro = Color.lerp(color, Colors.black, 0.35)!;

    // Sombra
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -9, 42, 28),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // Ruedas
    final rueda = Paint()..color = AppTheme.yellow;
    for (final dx in const [-13.0, 13.0]) {
      for (final dy in const [-17.0, 17.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(dx, dy), width: 14, height: 7),
            const Radius.circular(3),
          ),
          rueda,
        );
      }
    }

    // Cuerpo
    final cuerpo = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-20, -13, 40, 26),
      const Radius.circular(9),
    );
    canvas.drawRRect(cuerpo, Paint()..color = color);
    canvas.drawRRect(
      cuerpo,
      Paint()
        ..color = oscuro
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Parabrisas (hacia el frente)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, -9, 12, 18),
        const Radius.circular(5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Luces delanteras
    final luz = Paint()..color = AppTheme.yellow;
    canvas.drawCircle(const Offset(17, -8), 3, luz);
    canvas.drawCircle(const Offset(17, 8), 3, luz);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RobotPainter old) =>
      old.robotX != robotX ||
      old.robotY != robotY ||
      old.angle  != angle  ||
      old.collision  != collision  ||
      old.robotScale != robotScale ||
      old.trail.length     != trail.length ||
      old.obstacles.length != obstacles.length;
}

// ══════════════════════════════════════════════════════════════
//  Un comando del programa, ya separado en tipo y valor
// ══════════════════════════════════════════════════════════════

class _Cmd {
  final String tipo;   // 'AVANZAR' o 'GIRAR' ('?' si no se entiende)
  final double valor;  // cm o grados, con signo
  const _Cmd(this.tipo, this.valor);

  bool get esAvanzar => tipo == 'AVANZAR';
  bool get esGirar   => tipo == 'GIRAR';

  static _Cmd parse(String linea) {
    final partes = linea.trim().split(RegExp(r'\s+'));
    if (partes.length < 2) return const _Cmd('?', 0);
    return _Cmd(partes[0], double.tryParse(partes[1]) ?? 0);
  }
}

// ══════════════════════════════════════════════════════════════
//  Globo de Tita: blanco, con una colita que apunta a ella
// ══════════════════════════════════════════════════════════════

class _BurbujaMini extends StatelessWidget {
  final String texto;
  const _BurbujaMini({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: const Offset(1.5, 0),
          child: const CustomPaint(
            size: Size(10, 16),
            painter: _ColaIzquierdaPainter(),
          ),
        ),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                texto,
                key: ValueKey(texto),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.fuente(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4B4B4B),
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColaIzquierdaPainter extends CustomPainter {
  const _ColaIzquierdaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final relleno = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(relleno, Paint()..color = Colors.white);

    final lados = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height);
    canvas.drawPath(
      lados,
      Paint()
        ..color = const Color(0xFFE5E5E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ColaIzquierdaPainter old) => false;
}
