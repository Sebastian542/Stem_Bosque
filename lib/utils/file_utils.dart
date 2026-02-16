import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class FileUtils {
  /// Abre un archivo desde el directorio de StemBosque
  static Future<String?> openFile() async {
    try {
      // Obtener la ruta del directorio de StemBosque
      final directory = await getApplicationDocumentsDirectory();
      final stemBosqueDir = Directory('${directory.path}/StemBosque');

      // Crear el directorio si no existe
      if (!await stemBosqueDir.exists()) {
        await stemBosqueDir.create(recursive: true);
      }

      // OPCIÓN 1: Intentar con file_picker (puede tener limitaciones en Android)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'sb'], // Permitir .txt y .sb
        dialogTitle: 'Seleccionar programa',
        initialDirectory: stemBosqueDir.path, // ESTO puede no funcionar en Android
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        return content;
      }

      return null;
    } catch (e) {
      print('Error en FileUtils.openFile: $e');

      // FALLBACK: Si falla, intentar con método alternativo
      try {
        return await _openFileAlternative();
      } catch (e2) {
        print('Error en método alternativo: $e2');
        return null;
      }
    }
  }

  /// Método alternativo: Mostrar lista de archivos de StemBosque
  static Future<String?> _openFileAlternative() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stemBosqueDir = Directory('${directory.path}/StemBosque');

      if (!await stemBosqueDir.exists()) {
        return null;
      }

      // Listar todos los archivos .txt en el directorio
      List<FileSystemEntity> entities = stemBosqueDir.listSync();
      List<File> txtFiles = entities
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt') || file.path.endsWith('.sb'))
          .toList();

      if (txtFiles.isEmpty) {
        return null;
      }

      // Si solo hay un archivo, abrirlo directamente
      if (txtFiles.length == 1) {
        return await txtFiles.first.readAsString();
      }

      // Si hay múltiples archivos, aquí podrías mostrar un diálogo
      // Por ahora, retornamos el primero
      return await txtFiles.first.readAsString();

    } catch (e) {
      print('Error en _openFileAlternative: $e');
      return null;
    }
  }

  /// Guarda un archivo en el directorio de StemBosque
  static Future<bool> saveFile(String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stemBosqueDir = Directory('${directory.path}/StemBosque');

      // Crear directorio si no existe
      if (!await stemBosqueDir.exists()) {
        await stemBosqueDir.create(recursive: true);
      }

      // Guardar con nombre por defecto
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'programa_$timestamp.txt';
      final filePath = '${stemBosqueDir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(content);

      return await file.exists();
    } catch (e) {
      print('Error en FileUtils.saveFile: $e');
      return false;
    }
  }
}