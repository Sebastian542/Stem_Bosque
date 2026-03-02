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
  // Literales
  IDENTIFICADOR,
  NUMERO,
  TEXTO,
  // Operadores
  ASIGNACION,   // =
  IGUAL,        // ==
  MAYOR,        // >
  MENOR,        //
  // Puntuación
  DOS_PUNTOS,
  CORCHETE_IZQ,
  CORCHETE_DER,
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