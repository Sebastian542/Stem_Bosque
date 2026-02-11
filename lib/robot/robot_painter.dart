import 'dart:math';
import 'package:flutter/material.dart';
import 'robot.dart';

/// Painter personalizado para dibujar el robot y el fondo
class RobotPainter extends CustomPainter {
  final Robot robot;
  final bool showGrid;

  RobotPainter({
    required this.robot,
    this.showGrid = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujar cuadrícula de fondo
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // Dibujar robot
    _drawRobot(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 0.5;

    // Líneas verticales
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Líneas horizontales
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawRobot(Canvas canvas) {
    canvas.save();

    // Trasladar y rotar
    canvas.translate(robot.x, robot.y);
    canvas.rotate(robot.angle);

    // 1. Cuerpo del robot (rectángulo gris)
    final bodyPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      const Rect.fromLTWH(-20, -15, 40, 30),
      bodyPaint,
    );

    // 2. Ruedas/Orugas (rectángulos negros)
    final wheelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Rueda superior
    canvas.drawRect(
      const Rect.fromLTWH(-20, -20, 40, 5),
      wheelPaint,
    );

    // Rueda inferior
    canvas.drawRect(
      const Rect.fromLTWH(-20, 15, 40, 5),
      wheelPaint,
    );

    // 3. Cabeza/Torreta (círculo azul)
    final headPaint = Paint()
      ..color = Colors.blue.shade600
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset.zero,
      12,
      headPaint,
    );

    // 4. Indicador de dirección (línea roja)
    final directionPaint = Paint()
      ..color = Colors.red.shade600
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset.zero,
      const Offset(25, 0),
      directionPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(RobotPainter oldDelegate) {
    return oldDelegate.robot.x != robot.x ||
           oldDelegate.robot.y != robot.y ||
           oldDelegate.robot.angle != robot.angle;
  }
}
