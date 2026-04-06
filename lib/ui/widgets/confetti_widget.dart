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
    _pieces = List.generate(35, (i) => _Piece(
      x:     rng.nextDouble(),
      y:     -0.1 - rng.nextDouble() * 1.0,
      vx:    (rng.nextDouble() - 0.5) * 0.004,
      vy:    0.003 + rng.nextDouble() * 0.005,
      angle: rng.nextDouble() * 2 * pi,
      va:    (rng.nextDouble() - 0.5) * 0.15,
      size:  28 + rng.nextDouble() * 20,
      emoji: _emojis[i % _emojis.length],
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _EmojiPainter(_pieces, _ctrl.value),
        ),
      ),
    );
  }
}

class _Piece {
  double x, y;
  final double vx, vy, size, va;
  double angle;
  final String emoji;

  _Piece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.va,
    required this.size,
    required this.emoji,
  });
}

class _EmojiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;

  _EmojiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final x = (p.x + p.vx * t * 1000) * size.width;
      final y = (p.y + p.vy * t * 1000) * size.height;
      if (y > size.height + 60) continue;

      final angle = p.angle + p.va * t * 100;

      final tp = TextPainter(
        text: TextSpan(
          text: p.emoji,
          style: TextStyle(fontSize: p.size),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.translate(-tp.width / 2, -tp.height / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EmojiPainter old) => old.t != t;
}