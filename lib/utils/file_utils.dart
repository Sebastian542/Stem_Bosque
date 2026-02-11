import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Utilidades para manejo de archivos
class FileUtils {
  /// Abre un archivo y retorna su contenido
  static Future<String?> openFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['stb', 'txt'],
        dialogTitle: 'Abrir programa StemBosque',
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      throw Exception('Error al abrir archivo: $e');
    }
  }

  /// Guarda contenido en un archivo
  static Future<bool> saveFile(String content, {String? fileName}) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar programa',
        fileName: fileName ?? 'programa.stb',
        type: FileType.custom,
        allowedExtensions: ['stb', 'txt'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(content);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Error al guardar archivo: $e');
    }
  }

  /// Obtiene el directorio de documentos
  static Future<Directory> getDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Valida la extensión del archivo
  static bool isValidExtension(String path) {
    return path.toLowerCase().endsWith('.stb') ||
           path.toLowerCase().endsWith('.txt');
  }

  /// Obtiene el nombre del archivo desde su ruta
  static String getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }
}
