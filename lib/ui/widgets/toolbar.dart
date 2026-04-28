import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Barra de herramientas moderna con diseño Glassmorphism
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
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1f29).withAlpha(200),
        border: const Border(
          bottom: BorderSide(color: AppTheme.currentLine, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Botón principal: Ejecutar
            _buildActionButton(
              label: isRunning ? 'Ejecutando...' : 'Ejecutar',
              icon: isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: isRunning ? AppTheme.red : AppTheme.green,
              onPressed: onRun,
              isPrimary: true,
            ),

            const SizedBox(width: 12),
            const VerticalDivider(
                color: AppTheme.currentLine, indent: 20, endIndent: 20),
            const SizedBox(width: 8),

            // Acciones de archivo
            _buildIconButton(
                Icons.folder_open_rounded, 'Abrir', AppTheme.cyan, onOpen),
            _buildIconButton(
                Icons.save_rounded, 'Guardar', AppTheme.purple, onSave),
            _buildIconButton(Icons.delete_sweep_rounded, 'Limpiar',
                AppTheme.orange, onClear),

            const SizedBox(width: 12),

            // Badge de versión
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.currentLine,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'v0.6',
                style: TextStyle(
                  color: AppTheme.comment,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppTheme.background,
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: isPrimary ? 4 : 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildIconButton(
      IconData icon, String tooltip, Color color, VoidCallback? onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withAlpha(50), width: 1),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}