enum TipoToken {
  // Palabras clave
  PROGRAMA,
  FIN,
  GIRAR,
  AVANZAR,
  SI,
  ENTONCES,
  REPETIR,
  VECES,
  // Operadores booleanos
  AND,
  OR,
  NOT,
  // Funciones trigonométricas
  SEN,
  COS,
  TANG,
  // Literales
  IDENTIFICADOR,
  NUMERO,
  TEXTO,
  // Operadores aritméticos
  SUMA,       // +
  RESTA,      // -
  MULT,       // *
  DIV,        // /
  MODULO,     // %
  POTENCIA,   // ^
  // Operadores relacionales
  ASIGNACION, // =
  IGUAL,      // ==
  MAYOR,      // >
  MENOR,      // <
  // Puntuación
  DOS_PUNTOS,
  CORCHETE_IZQ,
  CORCHETE_DER,
  PAREN_IZQ,
  PAREN_DER,
  // Fin de archivo
  FIN_ARCHIVO,
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