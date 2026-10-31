import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'duo_button.dart';

/// Barra de herramientas: un botón grande para compilar y tres acciones de archivo.
/// La altura y el tamaño de los botones siguen el ancho real de la ventana.
class Toolbar extends StatelessWidget {
  final VoidCallback? onRun;
  final VoidCallback? onClear;
  final VoidCallback? onOpen;
  final VoidCallback? onSave;
  final bool isRunning;

  const Toolbar({
    super.key,
    this.onRun,
    this.onClear,
    this.onOpen,
    this.onSave,
    this.isRunning = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final compacto = r.denseControls;
    final altoBoton = compacto ? 34.0 : 44.0;
    final ladoIcono = compacto ? 36.0 : 44.0;

    return Container(
      height: r.toolbarHeight,
      padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(color: AppTheme.currentLine, width: AppTheme.borde),
        ),
      ),
      child: Row(
        children: [
          Flexible(
            child: DuoButton(
              label: isRunning
                  ? (compacto ? '...' : 'COMPILANDO...')
                  : 'COMPILAR',
              icon: isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: isRunning ? AppTheme.red : AppTheme.green,
              onPressed: onRun,
              height: altoBoton,
            ),
          ),
          SizedBox(width: compacto ? 8 : 18),
          DuoIconButton(
            icon: Icons.folder_open_rounded,
            color: AppTheme.cyan,
            tooltip: 'Abrir',
            onPressed: onOpen,
            size: ladoIcono,
          ),
          SizedBox(width: compacto ? 4 : 8),
          DuoIconButton(
            icon: Icons.save_rounded,
            color: AppTheme.purple,
            tooltip: 'Guardar',
            onPressed: onSave,
            size: ladoIcono,
          ),
          SizedBox(width: compacto ? 4 : 8),
          DuoIconButton(
            icon: Icons.delete_sweep_rounded,
            color: AppTheme.orange,
            tooltip: 'Limpiar',
            onPressed: onClear,
            size: ladoIcono,
          ),
        ],
      ),
    );
  }
}
