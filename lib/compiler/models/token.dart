enum TipoToken {
  // Palabras clave
  programa,
  fin,
  girar,
  avanzar,
  si,
  entonces,
  repetir,
  veces,
  // Literales
  identificador,
  numero,
  texto,
  // Operadores
  asignacion, // =
  igual, // ==
  mayor, // >
  menor, // <
  mas, // +
  menos, // -
  multiplicacion, // *
  division, // /
  // Puntuación
  dosPuntos,
  corcheteIzq,
  corcheteDer,
  // Expresiones aritmeticas
  sen,
  cos,
  tang,
  parentesisIzq,
  parentesisDer,
  // Operadores lógicos
  and,
  or,
  not,
  // Comandos personalizados de Firebase
  comandoCustom,
  // Fin de archivo
  finArchivo,
}

class Token {
  final TipoToken tipo;
  final String valor;
  final int linea;

  Token(this.tipo, this.valor, this.linea);

  @override
  String toString() =>
      'Token(${tipo.name.padRight(14)}, "${valor.padRight(12)}", línea: $linea)';
}