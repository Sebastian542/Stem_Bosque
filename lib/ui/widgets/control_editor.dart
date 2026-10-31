/// Control remoto del editor de código: deja que otras partes de la pantalla
/// (por ejemplo Tita) le pidan que lleve el cursor a una línea.
class ControlEditor {
  void Function(int linea)? _accion;

  /// Lo llama el editor para decir qué hacer cuando le piden ir a una línea.
  void vincular(void Function(int linea) accion) => _accion = accion;
  void desvincular() => _accion = null;

  /// Lleva el cursor al final de la línea [linea] (empieza en 1) y la muestra.
  void irALinea(int linea) => _accion?.call(linea);
}
