/// Define todos los tipos de tokens que puede reconocer el lexer
enum TokenType {
  // Palabras clave
  programa,
  fin,
  si,
  entonces,
  repetir,
  veces,
  
  // Comandos
  avanzar,
  girar,
  
  // Operadores
  igual,
  menorQue,
  mayorQue,
  igualIgual,
  
  // Delimitadores
  corcheteAbre,
  corcheteCierra,
  dobleComa,
  comillas,
  
  // Literales
  numero,
  cadena,
  identificador,
  
  // Especiales
  comentario,
  espacioBlanco,
  finArchivo,
  desconocido,
}

extension TokenTypeExtension on TokenType {
  String get displayName {
    switch (this) {
      case TokenType.programa:
        return 'PROGRAMA';
      case TokenType.fin:
        return 'FIN';
      case TokenType.si:
        return 'SI';
      case TokenType.entonces:
        return 'ENTONCES';
      case TokenType.repetir:
        return 'REPETIR';
      case TokenType.veces:
        return 'VECES';
      case TokenType.avanzar:
        return 'AVANZAR';
      case TokenType.girar:
        return 'GIRAR';
      default:
        return name.toUpperCase();
    }
  }
  
  bool get esPalabraClave {
    return [
      TokenType.programa,
      TokenType.fin,
      TokenType.si,
      TokenType.entonces,
      TokenType.repetir,
      TokenType.veces,
    ].contains(this);
  }
  
  bool get esComando {
    return [TokenType.avanzar, TokenType.girar].contains(this);
  }
}
