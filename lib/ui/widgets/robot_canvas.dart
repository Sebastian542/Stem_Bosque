import 'package:flutter/material.dart';
import '../../robot/robot.dart';
import '../../robot/robot_painter.dart';

/// Canvas donde se dibuja y anima el robot
class RobotCanvas extends StatefulWidget {
  final Robot robot;
  final bool showGrid;

  const RobotCanvas({
    Key? key,
    required this.robot,
    this.showGrid = true,
  }) : super(key: key);

  @override
  State<RobotCanvas> createState() => _RobotCanvasState();
}

class _RobotCanvasState extends State<RobotCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
    )..addListener(() {
        setState(() {
          widget.robot.update();
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void startAnimation() {
    if (!_animationController.isAnimating) {
      _animationController.repeat();
    }
  }

  void stopAnimation() {
    _animationController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Actualizar límites del robot
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.robot.checkBounds(
              constraints.maxWidth,
              constraints.maxHeight,
            );
          });

          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: RobotPainter(
              robot: widget.robot,
              showGrid: widget.showGrid,
            ),
          );
        },
      ),
    );
  }
}
