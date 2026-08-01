import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';

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

  // ── Control de animación ───────────────────────────────────
  bool   _isPlaying  = false;
  bool   _isDone     = false;
  int    _cmdIndex   = 0;       // comando actual
  int    _stepIndex  = 0;       // paso dentro del comando
  int    _totalSteps = 0;       // pasos totales del comando actual
  double _stepSize   = 0;       // magnitud por paso (avanzar)
  int    _stepSign   = 1;       // dirección (+1 / -1)

  static const double _rotSpeed  = 0.05;  // radianes por step (girar)
  static const double _moveSpeed = 5.0;   // px por step (avanzar)
  static const int    _stepMs    = 30;    // ms entre steps

  // ─────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // El robot empieza en el centro; se calcula en el primer build
  }

  void _initRobot(Size size) {
    if (_trail.isEmpty) {
      _x = size.width / 2;
      _y = size.height / 2;
      _trail.add(Offset(_x, _y));
    }
  }

  // ─────────────────────────────────────────────────────────
  // LÓGICA DE SIMULACIÓN
  // ─────────────────────────────────────────────────────────

  void _play() {
    if (_isPlaying || _isDone) return;
    setState(() => _isPlaying = true);
    _runNextCommand();
  }

  void _pause() => setState(() => _isPlaying = false);

  void _reset() {
    setState(() {
      _isPlaying  = false;
      _isDone     = false;
      _collisionDetected = false;
      _cmdIndex   = 0;
      _stepIndex  = 0;
      _trail.clear();
      // Recentrar — se recalcula en el próximo build
    });
  }

  void _runNextCommand() {
    if (!_isPlaying) return;

    if (_cmdIndex >= widget.commands.length) {
      setState(() { _isPlaying = false; _isDone = true; });
      return;
    }

    final line  = widget.commands[_cmdIndex].trim();
    final parts = line.split(' ');
    if (parts.length < 2) { _cmdIndex++; _runNextCommand(); return; }

    final cmd = parts[0];
    final val = double.tryParse(parts[1]) ?? 0;
    _stepSign  = val >= 0 ? 1 : -1;
    _totalSteps = val.abs().toInt();
    _stepIndex  = 0;

    if (cmd == 'AVANZAR') {
      _stepSize = _moveSpeed.toDouble();
      _animateSteps(_stepAvanzar);
    } else if (cmd == 'GIRAR') {
      _stepSize = _rotSpeed;
      _animateSteps(_stepGirar);
    } else {
      _cmdIndex++;
      _runNextCommand();
    }
  }

  void _animateSteps(VoidCallback stepFn) {
    if (!_isPlaying) return;
    if (_stepIndex >= _totalSteps) {
      _cmdIndex++;
      Future.delayed(Duration.zero, _runNextCommand);
      return;
    }
    stepFn();
    _stepIndex++;
    Future.delayed(const Duration(milliseconds: _stepMs), () => _animateSteps(stepFn));
  }

  void _stepAvanzar() {
    if (!mounted) return;

    final nextX = _x + _stepSign * _moveSpeed * cos(_angle);
    final nextY = _y + _stepSign * _moveSpeed * sin(_angle);

    // Detección de colisión básica
    // El robot mide aprox 40x30, usaremos un radio de seguridad
    final robotRect = Rect.fromCenter(center: Offset(nextX, nextY), width: 30, height: 30);
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
      return;
    }

    setState(() {
      _x = nextX;
      _y = nextY;
      _trail.add(Offset(_x, _y));
    });
  }

  void _addObstacle(Offset pos) {
    // Alinear a la cuadrícula (30px)
    final gx = (pos.dx / 30).floor() * 30.0;
    final gy = (pos.dy / 30).floor() * 30.0;
    final newObs = Rect.fromLTWH(gx, gy, 30, 30);

    setState(() {
      // Si ya existe uno ahí, lo quitamos (toggle)
      if (_obstacles.contains(newObs)) {
        _obstacles.remove(newObs);
      } else {
        _obstacles.add(newObs);
      }
    });
  }

  void _stepGirar() {
    if (!mounted) return;
    setState(() {
      _angle += _stepSign * _rotSpeed;
    });
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF282a36),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1e1f29),
        foregroundColor: const Color(0xFFf8f8f2),
        title: const Text(
          'Simulación',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: Color(0xFF50fa7b),
          ),
        ),
        actions: [
          // Botón Modo Edición
          IconButton(
            icon: Icon(_isEditMode ? Icons.layers : Icons.layers_outlined),
            color: _isEditMode ? const Color(0xFFffb86c) : const Color(0xFF6272a4),
            tooltip: 'Modo Bloque (Editar obstáculos)',
            onPressed: () => setState(() => _isEditMode = !_isEditMode),
          ),
          // Info de comandos
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${widget.commands.length} comandos',
                style: const TextStyle(
                  color: Color(0xFF6272a4),
                  fontFamily: 'monospace',
                  fontSize: 12,
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
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                _initRobot(size);
                return ClipRect(
                  child: GestureDetector(
                    onTapUp: _isEditMode ? (details) => _addObstacle(details.localPosition) : null,
                    child: CustomPaint(
                      size: size,
                      painter: _RobotPainter(
                        robotX:  _x,
                        robotY:  _y,
                        angle:   _angle,
                        trail:   List.unmodifiable(_trail),
                        obstacles: List.unmodifiable(_obstacles),
                        collision: _collisionDetected,
                      ),
                    ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final r = context.responsive;
        final narrow = constraints.maxWidth < 480;

        return Container(
          color: const Color(0xFF1e1f29),
          padding: EdgeInsets.symmetric(
            horizontal: r.horizontalPadding,
            vertical: r.verticalPadding * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: widget.commands.isEmpty
                    ? 0
                    : _cmdIndex / widget.commands.length,
                backgroundColor: const Color(0xFF44475a),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF50fa7b)),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              SizedBox(height: r.verticalPadding * 0.6),
              narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _statusText(),
                          textAlign: TextAlign.center,
                          style: _statusStyle(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CtrlButton(
                              icon: Icons.replay,
                              color: const Color(0xFFff5555),
                              tooltip: 'Reiniciar',
                              onPressed: _reset,
                            ),
                            const SizedBox(width: 10),
                            _CtrlButton(
                              icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: const Color(0xFF50fa7b),
                              tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
                              onPressed: _isDone
                                  ? null
                                  : _isPlaying ? _pause : _play,
                              large: true,
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _statusText(),
                            style: _statusStyle(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            _CtrlButton(
                              icon: Icons.replay,
                              color: const Color(0xFFff5555),
                              tooltip: 'Reiniciar',
                              onPressed: _reset,
                            ),
                            const SizedBox(width: 10),
                            _CtrlButton(
                              icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: const Color(0xFF50fa7b),
                              tooltip: _isPlaying ? 'Pausar' : 'Reproducir',
                              onPressed: _isDone
                                  ? null
                                  : _isPlaying ? _pause : _play,
                              large: true,
                            ),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  String _statusText() {
    if (_isDone) return '✓ Simulación completa';
    if (_isPlaying) return '▶ Ejecutando...';
    if (_cmdIndex == 0) return 'Listo para simular';
    return '⏸ Pausado (cmd $_cmdIndex/${widget.commands.length})';
  }

  TextStyle _statusStyle() {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: _isDone
          ? const Color(0xFF50fa7b)
          : _isPlaying
          ? const Color(0xFF8be9fd)
          : const Color(0xFF6272a4),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  CustomPainter del robot
// ══════════════════════════════════════════════════════════════

class _RobotPainter extends CustomPainter {
  final double robotX;
  final double robotY;
  final double angle;
  final List<Offset> trail;
  final List<Rect> obstacles;
  final bool collision;

  const _RobotPainter({
    required this.robotX,
    required this.robotY,
    required this.angle,
    required this.trail,
    this.obstacles = const [],
    this.collision = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo oscuro
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF282a36),
    );

    // Cuadrícula
    _drawGrid(canvas, size);

    // Obstáculos
    _drawObstacles(canvas);

    // Rastro
    _drawTrail(canvas);

    // Robot
    _drawRobot(canvas, size);

    if (collision) {
      _drawCollisionAlert(canvas, size);
    }
  }

  void _drawObstacles(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFff5555).withAlpha(180)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFff5555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var obs in obstacles) {
      canvas.drawRect(obs, paint);
      canvas.drawRect(obs, borderPaint);
    }
  }

  void _drawCollisionAlert(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '💥 COLISIÓN DETECTADA',
        style: TextStyle(
          color: Color(0xFFff5555),
          fontWeight: FontWeight.bold,
          fontSize: 20,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, 50),
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF44475a)
      ..strokeWidth = 0.5;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawTrail(Canvas canvas) {
    if (trail.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF8be9fd).withAlpha(120)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(trail.first.dx, trail.first.dy);
    for (int i = 1; i < trail.length; i++) {
      path.lineTo(trail[i].dx, trail[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawRobot(Canvas canvas, Size size) {
    // Escalar robot según el tamaño de la pantalla
    // Base: 400x800 -> scale 1.0
    final double scale = min(size.width / 400.0, size.height / 800.0).clamp(0.5, 2.0);

    canvas.save();
    canvas.translate(robotX, robotY);
    canvas.scale(scale);
    canvas.rotate(angle);

    // Cuerpo (rectángulo gris)
    canvas.drawRect(
      const Rect.fromLTWH(-20, -15, 40, 30),
      Paint()..color = collision ? const Color(0xFFff5555) : const Color(0xFF888888),
    );

    // Ruedas (rectángulos negros)
    final wheelPaint = Paint()..color = const Color(0xFF44475a);
    canvas.drawRect(const Rect.fromLTWH(-20, -20, 40, 5), wheelPaint);
    canvas.drawRect(const Rect.fromLTWH(-20, 15, 40, 5), wheelPaint);

    // Torreta (círculo azul)
    canvas.drawCircle(
      Offset.zero,
      12,
      Paint()..color = const Color(0xFF3498db),
    );

    // Indicador de frente (línea roja)
    canvas.drawLine(
      Offset.zero,
      const Offset(25, 0),
      Paint()
        ..color = const Color(0xFFff5555)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RobotPainter old) =>
      old.robotX != robotX ||
      old.robotY != robotY ||
      old.angle  != angle  ||
      old.trail.length != trail.length;
}

// ══════════════════════════════════════════════════════════════
//  Botón de control reutilizable
// ══════════════════════════════════════════════════════════════

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool large;

  const _CtrlButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 48.0 : 38.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onPressed != null
                ? color.withAlpha(30)
                : const Color(0xFF44475a).withAlpha(60),
            shape: BoxShape.circle,
            border: Border.all(
              color: onPressed != null ? color : const Color(0xFF44475a),
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: onPressed != null ? color : const Color(0xFF6272a4),
            size: large ? 24 : 20,
          ),
        ),
      ),
    );
  }
}
