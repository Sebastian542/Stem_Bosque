import 'package:flutter/material.dart';

/// Tema de la aplicación basado en Dracula
class AppTheme {
  // Colores Dracula
  static const Color background = Color(0xFF282a36);
  static const Color currentLine = Color(0xFF44475a);
  static const Color foreground = Color(0xFFf8f8f2);
  static const Color comment = Color(0xFF6272a4);
  static const Color cyan = Color(0xFF8be9fd);
  static const Color green = Color(0xFF50fa7b);
  static const Color orange = Color(0xFFffb86c);
  static const Color pink = Color(0xFFff79c6);
  static const Color purple = Color(0xFFbd93f9);
  static const Color red = Color(0xFFff5555);
  static const Color yellow = Color(0xFFf1fa8c);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: cyan,
        surface: currentLine,
        error: red,
      ),
      
      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1e1f29),
        foregroundColor: foreground,
        elevation: 0,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cyan,
          side: const BorderSide(color: cyan),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),

      // Text
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: foreground, fontSize: 16),
        bodyMedium: TextStyle(color: foreground, fontSize: 14),
        bodySmall: TextStyle(color: comment, fontSize: 12),
        titleLarge: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Icons
      iconTheme: const IconThemeData(
        color: foreground,
      ),

      // Divider
      dividerColor: currentLine,
    );
  }

  // Colores para syntax highlighting
  static const Map<String, Color> syntaxColors = {
    'keyword': pink,
    'command': cyan,
    'comment': green,
    'number': purple,
    'string': orange,
    'identifier': foreground,
  };

  // Estilos de texto para el editor
  static TextStyle getCodeStyle(String type) {
    return TextStyle(
      color: syntaxColors[type] ?? foreground,
      fontFamily: 'monospace',
      fontSize: 16,
      fontWeight: type == 'keyword' ? FontWeight.bold : FontWeight.normal,
    );
  }
}
