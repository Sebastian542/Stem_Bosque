import 'dart:math';

/// Representa el robot que se mueve en el canvas
class Robot {
  double x;
  double y;
  double angle; // En radianes
  double speed;
  final double maxSpeed;
  final double rotationSpeed;

  Robot({
    required this.x,
    required this.y,
    this.angle = 0,
    this.speed = 0,
    this.maxSpeed = 5,
    this.rotationSpeed = 0.05,
  });

  /// Avanza en la dirección actual
  void avanzar(int direction) {
    if (direction > 0) {
      speed = maxSpeed;
    } else if (direction < 0) {
      speed = -maxSpeed;
    }
  }

  /// Gira el robot
  void girar(int direction) {
    if (direction > 0) {
      angle += rotationSpeed;
    } else if (direction < 0) {
      angle -= rotationSpeed;
    }
  }

  /// Detiene el robot
  void detener() {
    speed = 0;
  }

  /// Actualiza la posición del robot
  void update() {
    x += speed * cos(angle);
    y += speed * sin(angle);
    detener();
  }

  /// Verifica los bordes y hace wrap-around
  void checkBounds(double width, double height) {
    if (x > width) x = 0;
    if (x < 0) x = width;
    if (y > height) y = 0;
    if (y < 0) y = height;
  }

  /// Reinicia el robot al centro
  void reset(double width, double height) {
    x = width / 2;
    y = height / 2;
    angle = 0;
    speed = 0;
  }

  /// Crea una copia del robot
  Robot copy() {
    return Robot(
      x: x,
      y: y,
      angle: angle,
      speed: speed,
      maxSpeed: maxSpeed,
      rotationSpeed: rotationSpeed,
    );
  }
}