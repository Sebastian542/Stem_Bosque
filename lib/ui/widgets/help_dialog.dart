import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        backgroundColor: AppTheme.background,
        surfaceTintColor: AppTheme.purple,
        insetPadding: EdgeInsets.symmetric(
          horizontal: r.isCompact ? 16 : 24,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.purple, width: 1),
        ),
        titlePadding: EdgeInsets.zero,
        title: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, color: AppTheme.cyan),
                  SizedBox(width: 12),
                  Text('Documentación', style: TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            TabBar(
              labelColor: AppTheme.cyan,
              unselectedLabelColor: AppTheme.comment,
              indicatorColor: AppTheme.cyan,
              dividerColor: AppTheme.currentLine,
              tabs: const [
                Tab(text: 'Conceptos'),
                Tab(text: 'Comandos DSL'),
              ],
            ),
          ],
        ),
        content: SizedBox(
          width: r.dialogMaxWidth,
          height: r.dialogListHeight,
          child: TabBarView(
            children: [
              _buildConceptosTab(),
              _buildComandosTab(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO', style: TextStyle(color: AppTheme.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpItem('kw', 'Keyword', 'Palabras reservadas que definen la estructura del código.', AppTheme.pink),
          _buildHelpItem('cmd', 'Command', 'Instrucciones directas para el robot (mover, girar).', AppTheme.cyan),
          _buildHelpItem('trig', 'Trigger', 'Sensores o eventos que activan una respuesta.', AppTheme.green),
          _buildHelpItem('bol', 'Boolean', 'Valores de verdad (verdadero/falso).', AppTheme.yellow),
          _buildHelpItem('var', 'Variable', 'Espacios para guardar valores cambiantes.', AppTheme.orange),
          _buildHelpItem('str', 'String', 'Cadenas de texto o mensajes entre comillas.', AppTheme.purple),
        ],
      ),
    );
  }

  Widget _buildComandosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDslCategory('ESTRUCTURA', [
            {'cmd': 'PROGRAMA "nombre"', 'desc': 'Inicia el programa con un nombre.'},
            {'cmd': 'FIN', 'desc': 'Indica el final del bloque o programa.'},
          ]),
          _buildDslCategory('MOVIMIENTO', [
            {'cmd': 'AVANZAR [distancia]', 'desc': 'Mueve el robot hacia adelante.'},
            {'cmd': 'GIRAR [grados]', 'desc': 'Rota el robot a la derecha.'},
          ]),
          _buildDslCategory('CONTROL', [
            {'cmd': 'SI [condicion] ENTONCES', 'desc': 'Ejecuta si se cumple la condición.'},
            {'cmd': 'REPETIR [n] VECES', 'desc': 'Repite un bloque de código.'},
          ]),
          _buildDslCategory('MATEMÁTICAS', [
            {'cmd': 'SEN, COS, TANG', 'desc': 'Funciones trigonométricas.'},
            {'cmd': 'AND, OR, NOT', 'desc': 'Operadores lógicos.'},
          ]),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String short, String full, String description, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color, width: 1),
                ),
                child: Text(short, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(full, style: const TextStyle(color: AppTheme.foreground, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: AppTheme.comment, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildDslCategory(String title, List<Map<String, String>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.comment, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['cmd']!, style: const TextStyle(color: AppTheme.green, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
              Text(item['desc']!, style: const TextStyle(color: AppTheme.foreground, fontSize: 11)),
            ],
          ),
        )),
        const Divider(color: AppTheme.currentLine),
        const SizedBox(height: 8),
      ],
    );
  }
}
