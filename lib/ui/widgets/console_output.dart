import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tipos de mensajes en la consola
enum LogType {
  info,
  success,
  error,
  warning,
}

/// Mensaje de log en la consola
class LogMessage {
  final String message;
  final LogType type;
  final DateTime timestamp;

  LogMessage({
    required this.message,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Color get color {
    switch (type) {
      case LogType.info:
        return AppTheme.cyan;
      case LogType.success:
        return AppTheme.green;
      case LogType.error:
        return AppTheme.red;
      case LogType.warning:
        return AppTheme.yellow;
    }
  }

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}

/// Consola de salida para mostrar logs
class ConsoleOutput extends StatefulWidget {
  final List<LogMessage> messages;
  final VoidCallback? onClear;

  const ConsoleOutput({
    Key? key,
    required this.messages,
    this.onClear,
  }) : super(key: key);

  @override
  State<ConsoleOutput> createState() => _ConsoleOutputState();
}

class _ConsoleOutputState extends State<ConsoleOutput> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConsoleOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      // Auto-scroll al final cuando hay nuevos mensajes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF191a21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header de la consola
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.currentLine,
              border: Border(
                bottom: BorderSide(color: Colors.black.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: AppTheme.green),
                const SizedBox(width: 8),
                const Text(
                  'Consola',
                  style: TextStyle(
                    color: AppTheme.foreground,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (widget.onClear != null)
                  IconButton(
                    icon: const Icon(Icons.clear_all, size: 18),
                    onPressed: widget.onClear,
                    tooltip: 'Limpiar consola',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          
          // Mensajes
          Expanded(
            child: widget.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      return _buildLogMessage(widget.messages[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        '> Esperando ejecución...',
        style: TextStyle(
          color: AppTheme.comment,
          fontFamily: 'monospace',
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildLogMessage(LogMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: message.color, width: 3),
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text: '[${message.formattedTime}] ',
                style: const TextStyle(color: AppTheme.comment),
              ),
              TextSpan(
                text: message.message,
                style: TextStyle(color: message.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
