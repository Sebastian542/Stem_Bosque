/// Ejemplo de cómo se escribe bien un bloque del lenguaje.
class EjemploSintaxis {
  final String titulo;
  final String codigo;
  const EjemploSintaxis(this.titulo, this.codigo);
}

/// Cuando el estudiante se equivoca, [SyntaxValidator] muestra, además del
/// mensaje, un cuadrito con el ejemplo del bloque que estaba escribiendo
/// (un SI, un REPETIR, un GIRAR...). Todos los ejemplos son programas válidos.
class AyudaSintaxis {
  static const programa = EjemploSintaxis(
    'Así se escribe un programa',
    'PROGRAMA "Mi robot"\n'
        '  AVANZAR 20\n'
        '  GIRAR 90\n'
        'FIN PROGRAMA',
  );

  static const condicional = EjemploSintaxis(
    'Así se escribe un SI',
    'N = 5\n'
        'SI N < 10 ENTONCES:\n'
        '  AVANZAR 5\n'
        'FIN SI',
  );

  static const ciclo = EjemploSintaxis(
    'Así se escribe un REPETIR',
    'N = 4\n'
        'REPETIR [N] VECES:\n'
        '  AVANZAR 20\n'
        '  GIRAR 90\n'
        'FIN REPETIR',
  );

  static const girar = EjemploSintaxis(
    'Así se usa GIRAR',
    'GIRAR 90    // derecha\n'
        'GIRAR -45   // izquierda',
  );

  static const avanzar = EjemploSintaxis(
    'Así se usa AVANZAR',
    'AVANZAR 20   // adelante\n'
        'AVANZAR -5   // atrás',
  );

  static const variable = EjemploSintaxis(
    'Así se guarda un número',
    'N = 10\n'
        'Pasos = 3\n'
        'A = SEN(30)',
  );

  static const funciones = EjemploSintaxis(
    'Así se usan SEN, COS y TANG',
    'AVANZAR SEN(30)\n'
        'GIRAR COS(60)\n'
        'A = TANG(45)',
  );

  static const ordenes = EjemploSintaxis(
    'Estas son las órdenes básicas',
    'AVANZAR 10   // mover\n'
        'GIRAR 90     // girar\n'
        'N = 5        // guardar un número',
  );

  /// Ejemplo que corresponde al lugar del error, o null si no hay código.
  ///
  /// [linea] es la línea del error (empieza en 1) o null si no se conoce.
  /// [mensaje] es el mensaje del error: sirve para los casos en que la línea
  /// no basta (por ejemplo, cuando falta el final del programa).
  static EjemploSintaxis? para(String fuente, int? linea,
      {String mensaje = ''}) {
    if (fuente.trim().isEmpty) return programa;

    // Cierres mezclados: el mensaje dice cuál era el bloque.
    if (mensaje.contains('el SI no se cerró') ||
        mensaje.contains('FIN SI pero')) {
      return condicional;
    }
    if (mensaje.contains('el REPETIR no se cerró') ||
        mensaje.contains('FIN REPETIR pero')) {
      return ciclo;
    }

    // Errores de la estructura del programa: el ejemplo es el programa completo.
    // (Si no, se elegiría por la palabra de la línea: "Girar = 2" mostraría GIRAR.)
    if (mensaje.contains('tiene que empezar con la palabra PROGRAMA') ||
        mensaje.contains('a PROGRAMA le falta el nombre') ||
        mensaje.contains('hay texto después de FIN PROGRAMA') ||
        mensaje.contains('tu programa está vacío')) {
      return programa;
    }

    // "¿Quisiste escribir AVANZAR?": el ejemplo de esa orden.
    final quiso = RegExp(r'Quisiste escribir (\w+)').firstMatch(mensaje);
    if (quiso != null) {
      switch (quiso.group(1)) {
        case 'AVANZAR':
          return avanzar;
        case 'GIRAR':
          return girar;
        case 'REPETIR':
        case 'VECES':
          return ciclo;
        case 'ENTONCES':
          return condicional;
        case 'PROGRAMA':
          return programa;
      }
    }

    final lineas = _sinComentarios(fuente).split('\n');
    var idx = linea == null ? lineas.length - 1 : linea - 1;
    if (idx < 0) idx = 0;
    if (idx > lineas.length - 1) idx = lineas.length - 1;

    final faltaElFinal = mensaje.contains('falta el final del programa');
    final faltaCerrar  = mensaje.contains('falta cerrar un bloque');

    // Bloques que estaban abiertos antes del lugar del error.
    final hasta = faltaElFinal ? lineas.length : idx;
    final abiertos = <String>[];
    for (var i = 0; i < hasta; i++) {
      final p = _palabras(lineas[i]);
      if (p.isEmpty) continue;
      if (p[0] == 'SI') {
        abiertos.add('SI');
      } else if (p[0] == 'REPETIR') {
        abiertos.add('REPETIR');
      } else if (p[0] == 'FIN') {
        final que = p.length > 1 ? p[1] : '';
        if (que == 'SI' || que == 'REPETIR') {
          final k = abiertos.lastIndexOf(que);
          if (k >= 0) abiertos.removeAt(k);
        }
      }
    }

    if (faltaElFinal || faltaCerrar) return _bloqueAbierto(abiertos);

    final p = _palabras(lineas[idx]);
    if (p.isEmpty) return _bloqueAbierto(abiertos);

    switch (p[0]) {
      case 'PROGRAMA':
        return programa;
      case 'SI':
      case 'ENTONCES':
        return condicional;
      case 'REPETIR':
      case 'VECES':
        return ciclo;
      case 'GIRAR':
        return girar;
      case 'AVANZAR':
        return avanzar;
      case 'SEN':
      case 'COS':
      case 'TANG':
        return funciones;
      case 'FIN':
        final que = p.length > 1 ? p[1] : '';
        if (que == 'SI') return condicional;
        if (que == 'REPETIR') return ciclo;
        if (que == 'PROGRAMA') return programa;
        return _bloqueAbierto(abiertos);
    }

    // ¿Parece una asignación (o un nombre suelto)?
    if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*\s*(=|$)')
        .hasMatch(lineas[idx].trim())) {
      return variable;
    }
    return ordenes;
  }

  static EjemploSintaxis _bloqueAbierto(List<String> abiertos) {
    if (abiertos.isEmpty) return programa;
    return abiertos.last == 'SI' ? condicional : ciclo;
  }

  /// Quita las notas (// y /* */) conservando los saltos de línea, para que los
  /// números de línea sigan coincidiendo con los del editor.
  static String _sinComentarios(String s) {
    final sinBloques = s.replaceAllMapped(
      RegExp(r'/\*[\s\S]*?\*/'),
      (m) => m.group(0)!.replaceAll(RegExp(r'[^\n]'), ' '),
    );
    return sinBloques.split('\n').map((l) {
      final i = l.indexOf('//');
      return i >= 0 ? l.substring(0, i) : l;
    }).join('\n');
  }

  /// Palabras de la línea (mayúsculas), ignorando el contenido de los textos.
  /// Vacío si la línea está en blanco o no empieza con una letra.
  static List<String> _palabras(String linea) {
    final t = linea.trimLeft();
    if (t.isEmpty || !RegExp(r'^[A-Za-z_]').hasMatch(t)) return const [];
    final sinTextos = t.replaceAll(RegExp(r'"[^"]*"'), '""');
    return RegExp(r'[A-Za-z_]+')
        .allMatches(sinTextos)
        .map((m) => m.group(0)!.toUpperCase())
        .toList();
  }
}
