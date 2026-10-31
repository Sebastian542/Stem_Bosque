import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botón grande con "borde de abajo" que se hunde al apretarlo (estilo Duolingo).
///
/// Se adapta al espacio que le da su padre: dentro de un [Expanded] ocupa todo
/// el ancho; en un [Row] normal, solo lo que necesita su contenido.
/// Con [onPressed] nulo se ve apagado (gris) y no responde.
class DuoButton extends StatefulWidget {
  final String        label;
  final IconData?     icon;
  final Color         color;
  final VoidCallback? onPressed;
  final double        height;

  const DuoButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.height = 46,
  });

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton> {
  static const _borde = 4.0; // alto del "borde de abajo"
  bool _apretado = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.onPressed != null;
    final fondo  = activo ? widget.color : AppTheme.selection;
    final sombra = activo
        ? Color.lerp(widget.color, Colors.black, 0.30)!
        : AppTheme.currentLine;
    final texto  = activo ? AppTheme.background : AppTheme.comment;

    return Semantics(
      button:  true,
      enabled: activo,
      label:   widget.label,
      child: SizedBox(
        height: widget.height + _borde,
        child: GestureDetector(
          behavior:    HitTestBehavior.opaque,
          onTapDown:   activo ? (_) => setState(() => _apretado = true) : null,
          onTapCancel: activo ? () => setState(() => _apretado = false) : null,
          onTapUp: activo
              ? (_) {
                  setState(() => _apretado = false);
                  widget.onPressed!();
                }
              : null,
          child: AnimatedContainer(
            duration:  const Duration(milliseconds: 80),
            height:    widget.height,
            padding:   const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            transform: Matrix4.translationValues(0, _apretado ? _borde : 0, 0),
            decoration: BoxDecoration(
              color:        fondo,
              borderRadius: BorderRadius.circular(AppTheme.radioBoton),
              boxShadow: (_apretado || !activo)
                  ? const []
                  : [BoxShadow(color: sombra, offset: const Offset(0, _borde))],
            ),
            child: Row(
              mainAxisSize:      MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: texto),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.fuente(
                      fontSize:      14,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 0.8,
                      color:         texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado con un ícono y borde fino, para las acciones secundarias.
/// Con [onPressed] nulo se ve apagado.
class DuoIconButton extends StatelessWidget {
  final IconData      icon;
  final Color         color;
  final String        tooltip;
  final VoidCallback? onPressed;
  final double        size;
  final Color?        fondo; // relleno opcional (por ejemplo, si flota sobre otra cosa)

  const DuoIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.fondo,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null;
    final radio  = BorderRadius.circular(AppTheme.radioBoton);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:        onPressed,
          borderRadius: radio,
          child: Container(
            width:  size,
            height: size,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: radio,
              border: Border.all(
                color: AppTheme.selection,
                width: AppTheme.borde,
              ),
            ),
            child: Icon(
              icon,
              size:  22,
              color: activo ? color : AppTheme.comment.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
