import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiWidget extends StatefulWidget {
  const ConfettiWidget({super.key});

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Piece> _pieces;

  static const _emojis = [
    '🦦','🎉','⭐','💥','🎊','✨','🏆','💚','🎶',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..forward();

    final rng = Random();
    _pieces = List.generate(35, (i) {
      final size = 28 + rng.nextDouble() * 20;
      return _Piece(
        x:     rng.nextDouble(),
        y:     -0.1 - rng.nextDouble() * 1.0,
        vx:    (rng.nextDouble() - 0.5) * 0.004,
        vy:    0.003 + rng.nextDouble() * 0.005,
        angle: rng.nextDouble() * 2 * pi,
        va:    (rng.nextDouble() - 0.5) * 0.15,
        // El texto se mide una sola vez: en cada fotograma solo se mueve.
        painter: TextPainter(
          text: TextSpan(
            text: _emojis[i % _emojis.length],
            style: TextStyle(fontSize: size),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    for (final p in _pieces) {
      p.painter.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: MediaQuery.sizeOf(context),
          painter: _EmojiPainter(_pieces, _ctrl),
        ),
      ),
    );
  }
}

class _Piece {
  final double x, y, vx, vy, angle, va;
  final TextPainter painter;

  _Piece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.va,
    required this.painter,
  });
}

class _EmojiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final Animation<double> anim;

  _EmojiPainter(this.pieces, this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final p in pieces) {
      final x = (p.x + p.vx * t * 1000) * size.width;
      final y = (p.y + p.vy * t * 1000) * size.height;
      if (y > size.height + 60 || y < -60) continue;

      final tp = p.painter;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + p.va * t * 100);
      canvas.translate(-tp.width / 2, -tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EmojiPainter old) =>
      old.pieces != pieces || old.anim != anim;
}
