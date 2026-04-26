import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta Dracula Extendida
  static const Color background = Color(0xFF21222C);
  static const Color currentLine = Color(0xFF343746);
  static const Color foreground = Color(0xFFF8F8F2);
  static const Color comment = Color(0xFF6272A4);
  static const Color cyan = Color(0xFF8BE9FD);
  static const Color green = Color(0xFF50FA7B);
  static const Color orange = Color(0xFFFFB86C);
  static const Color pink = Color(0xFFFF79C6);
  static const Color purple = Color(0xFFBD93F9);
  static const Color red = Color(0xFFFF5555);
  static const Color yellow = Color(0xFFF1FA8C);

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
        onSurface: foreground,
      ),
      
      textTheme: GoogleFonts.poppinsTextTheme(const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        bodyLarge: TextStyle(fontSize: 16),
      )),

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF191A21),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF282A36),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF191A21),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: purple, width: 1.5),
        ),
      ),
    );
  }

  // Estilos de Código Profesionales
  static TextStyle get codeStyle => GoogleFonts.jetBrainsMono(
    fontSize: 15,
    height: 1.5,
  );

  static const Map<String, Color> syntaxColors = {
    'keyword': pink,
    'command': cyan,
    'comment': green,
    'number': purple,
    'string': orange,
    'identifier': foreground,
  };

  static TextStyle getCodeStyle(String type) {
    return codeStyle.copyWith(
      color: syntaxColors[type] ?? foreground,
      fontWeight: type == 'keyword' ? FontWeight.bold : FontWeight.normal,
    );
  }
}
