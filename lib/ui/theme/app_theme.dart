import 'package:flutter/material.dart';

/// Sistema de diseño de STEMBosque.
///
/// Una sola idea para toda la app: fondo oscuro azul-verdoso, bordes de 2 px en
/// vez de sombras, esquinas redondeadas y colores brillantes y amigables
/// (inspirado en Duolingo). Todo se define aquí: si algo se ve distinto en
/// alguna pantalla, casi seguro es un color que no sale de este archivo.
class AppTheme {
  // ── Neutros ────────────────────────────────────────────────────────────────
  // (los nombres se conservan del tema anterior para no tocar el resto del código)
  static const Color background  = Color(0xFF131F24); // página, barras y editor
  static const Color currentLine = Color(0xFF1F2F36); // tarjetas, diálogos, globos
  static const Color selection   = Color(0xFF37464F); // bordes y divisores
  static const Color foreground  = Color(0xFFEEF4F7); // texto principal
  static const Color comment     = Color(0xFF8099A5); // texto secundario y notas

  // ── Colores de acento ──────────────────────────────────────────────────────
  static const Color green  = Color(0xFF58CC02); // acción principal, variables
  static const Color cyan   = Color(0xFF1CB0F6); // órdenes, enlaces, cursor
  static const Color orange = Color(0xFFFF9600); // avisos, errores amables
  static const Color pink   = Color(0xFFFF86D0); // palabras del lenguaje
  static const Color purple = Color(0xFFCE82FF); // números
  static const Color red    = Color(0xFFFF4B4B); // errores graves, acciones peligrosas
  static const Color yellow = Color(0xFFFFC800); // textos entre comillas

  // ── Formas ─────────────────────────────────────────────────────────────────
  static const double radioBoton   = 14;
  static const double radioTarjeta = 18;
  static const double borde        = 2;

  // ── Tipografía (archivos en assets/fonts, declarados en pubspec.yaml) ──────
  static const String familia     = 'Nunito';
  static const String familiaMono = 'JetBrainsMono';

  /// Tipografía de la app (una sola fuente, redondeada y amable).
  static TextStyle fuente({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: familia,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  /// El tema se arma una sola vez: MaterialApp lo compara en cada build.
  static final ThemeData darkTheme = _crearTema();

  static ThemeData _crearTema() {
    final borde2 = BorderSide(color: selection, width: borde);
    final formaBoton =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioBoton));

    OutlineInputBorder campo(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radioBoton),
          borderSide: BorderSide(color: color, width: borde),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: green,
        onPrimary: background,
        secondary: cyan,
        onSecondary: background,
        tertiary: purple,
        surface: currentLine,
        onSurface: foreground,
        error: red,
        outline: selection,
      ),

      fontFamily: familia,
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: familia,
            bodyColor: foreground,
            displayColor: foreground,
          ),

      // ── Barra superior: plana, con una línea abajo ──
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: borde2),
        iconTheme: const IconThemeData(color: foreground),
        titleTextStyle: fuente(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),

      // ── Tarjetas y diálogos: borde fino en lugar de sombra ──
      cardTheme: CardThemeData(
        color: currentLine,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioTarjeta),
          side: borde2,
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: currentLine,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: borde2,
        ),
        titleTextStyle: fuente(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
        contentTextStyle: fuente(fontSize: 14, color: foreground, height: 1.4),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: currentLine,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: currentLine,
        contentTextStyle: fuente(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioBoton),
          side: borde2,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: currentLine,
          borderRadius: BorderRadius.circular(10),
          border: Border.fromBorderSide(borde2),
        ),
        textStyle: fuente(fontSize: 12, color: foreground),
      ),
      dividerTheme: const DividerThemeData(
        color: selection,
        thickness: 1.5,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: green),

      // ── Botones ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: background,
          disabledBackgroundColor: selection,
          disabledForegroundColor: comment,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: formaBoton,
          textStyle: fuente(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: background,
          shape: formaBoton,
          textStyle: fuente(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cyan,
          shape: formaBoton,
          textStyle: fuente(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: borde2,
          shape: formaBoton,
          textStyle: fuente(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),

      // ── Campos de texto ──
      // (el editor de código los desactiva a propósito: ver code_editor_validated)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: fuente(color: comment),
        labelStyle: fuente(color: comment),
        floatingLabelStyle: fuente(color: cyan, fontWeight: FontWeight.w700),
        border: campo(selection),
        enabledBorder: campo(selection),
        focusedBorder: campo(cyan),
        errorBorder: campo(red),
        focusedErrorBorder: campo(red),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color(0x401CB0F6), // azul con poca opacidad
        cursorColor: cyan,
        selectionHandleColor: cyan,
      ),
    );
  }

  // Estilos de Código Profesionales
  static const TextStyle codeStyle = TextStyle(
    fontFamily: familiaMono,
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
