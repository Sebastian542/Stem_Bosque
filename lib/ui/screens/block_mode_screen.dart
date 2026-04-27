import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BlockModeScreen extends StatefulWidget {
  const BlockModeScreen({super.key});

  @override
  State<BlockModeScreen> createState() => _BlockModeScreenState();
}

class _BlockModeScreenState extends State<BlockModeScreen> {
  final List<DraggableComponent> _components = [
    DraggableComponent(name: 'Arbusto', icon: Icons.park, color: AppTheme.green),
    DraggableComponent(name: 'Piedra', icon: Icons.landscape, color: AppTheme.comment),
    DraggableComponent(name: 'Sensor', icon: Icons.settings_input_component, color: AppTheme.cyan),
    DraggableComponent(name: 'Robot', icon: Icons.smart_toy, color: AppTheme.purple),
  ];

  final List<PlacedComponent> _placedComponents = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Modo Bloque - Simulación'),
        backgroundColor: AppTheme.currentLine,
      ),
      body: Column(
        children: [
          // Área de herramientas
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: AppTheme.currentLine.withAlpha(50),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _components.length,
              itemBuilder: (context, index) {
                final component = _components[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Draggable<DraggableComponent>(
                    data: component,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Icon(component.icon, size: 50, color: component.color.withAlpha(150)),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: _buildToolItem(component),
                    ),
                    child: _buildToolItem(component),
                  ),
                );
              },
            ),
          ),
          
          const Divider(height: 1, color: AppTheme.comment),

          // Área de simulación / Drop Zone
          Expanded(
            child: DragTarget<DraggableComponent>(
              onAcceptWithDetails: (details) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final localOffset = renderBox.globalToLocal(details.offset);
                // Ajustar offset por la altura de la AppBar y el área de herramientas
                // En una app real usaríamos un LayoutBuilder para mayor precisión
                setState(() {
                  _placedComponents.add(PlacedComponent(
                    component: details.data,
                    position: localOffset,
                  ));
                });
              },
              builder: (context, candidateData, rejectedData) {
                return Stack(
                  children: [
                    // Cuadrícula de fondo
                    _buildGrid(),
                    
                    // Componentes colocados
                    ..._placedComponents.map((pc) => Positioned(
                      left: pc.position.dx - 20,
                      top: pc.position.dy - 120, // Ajuste manual aproximado
                      child: GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _placedComponents.remove(pc);
                          });
                        },
                        child: Icon(pc.component.icon, size: 40, color: pc.component.color),
                      ),
                    )),

                    if (candidateData.isNotEmpty)
                      Container(
                        color: AppTheme.cyan.withAlpha(30),
                        child: const Center(
                          child: Text('Suelta para colocar', style: TextStyle(color: AppTheme.cyan)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          // Ayuda
          Container(
            padding: const EdgeInsets.all(8),
            color: AppTheme.currentLine,
            child: const Text(
              'Arrastra elementos al escenario. Mantén presionado para eliminar.',
              style: TextStyle(color: AppTheme.comment, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem(DraggableComponent component) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: component.color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: component.color.withAlpha(50)),
          ),
          child: Icon(component.icon, color: component.color, size: 30),
        ),
        const SizedBox(height: 4),
        Text(component.name, style: const TextStyle(color: AppTheme.foreground, fontSize: 10)),
      ],
    );
  }

  Widget _buildGrid() {
    return CustomPaint(
      painter: GridPainter(),
      child: Container(),
    );
  }
}

class DraggableComponent {
  final String name;
  final IconData icon;
  final Color color;

  DraggableComponent({required this.name, required this.icon, required this.color});
}

class PlacedComponent {
  final DraggableComponent component;
  final Offset position;

  PlacedComponent({required this.component, required this.position});
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.comment.withAlpha(30)
      ..strokeWidth = 0.5;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
