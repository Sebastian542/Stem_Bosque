/// Tipos de instrucciones ejecutables
enum InstructionType {
  avanzar,
  girar,
  asignar,
}

/// Representa una instrucción ejecutable del robot
class Instruction {
  final InstructionType type;
  final int value;
  final String? variable;

  Instruction({
    required this.type,
    required this.value,
    this.variable,
  });

  @override
  String toString() {
    switch (type) {
      case InstructionType.avanzar:
        return 'AVANZAR $value';
      case InstructionType.girar:
        return 'GIRAR $value';
      case InstructionType.asignar:
        return '$variable = $value';
    }
  }

  /// Crea una instrucción de avanzar
  factory Instruction.avanzar(int distancia) {
    return Instruction(
      type: InstructionType.avanzar,
      value: distancia,
    );
  }

  /// Crea una instrucción de girar
  factory Instruction.girar(int angulo) {
    return Instruction(
      type: InstructionType.girar,
      value: angulo,
    );
  }

  /// Crea una instrucción de asignación
  factory Instruction.asignar(String variable, int value) {
    return Instruction(
      type: InstructionType.asignar,
      value: value,
      variable: variable,
    );
  }
}
