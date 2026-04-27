import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'file_manager_stub.dart'
    if (dart.library.html) 'web_downloader.dart';

class FileManager {
  static final FileManager instance = FileManager._internal();
  FileManager._internal();

  static const String _autoSaveFileName = 'stembosque_current_program.sb';

  String? currentFilePath;
  String? lastSavedContent;

  bool hasUnsavedChanges(String currentContent) {
    if (lastSavedContent == null) return true;
    return currentContent != lastSavedContent;
  }

  Future<Directory> getAppDirectory() async {
    final dir    = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/StemBosque');
    if (!await appDir.exists()) await appDir.create(recursive: true);
    return appDir;
  }

  /// Guarda el archivo. En PC/Web abre un selector para elegir ubicación (Windows Explorer).
  Future<bool> saveToFile(String content, {String? customFileName}) async {
    if (kIsWeb) {
      downloadWebFile(content, customFileName ?? 'programa.sb');
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.linux || 
        defaultTargetPlatform == TargetPlatform.macOS) {
      
      // En PC, si saveFile falla, usamos pickDirectory como el flujo de abrir
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecciona la carpeta para guardar tu programa',
      );

      if (selectedDirectory == null) return false;

      try {
        final fileName = customFileName ?? 'programa.sb';
        final file = File('$selectedDirectory/$fileName');
        await file.writeAsString(content);
        currentFilePath = file.path;
        lastSavedContent = content;
        return true;
      } catch (e) {
        debugPrint('Error guardando en PC: $e');
        return false;
      }
    }

    // Caso Android (Original)
    try {
      final dir = await getAppDirectory();
      final fileName = customFileName ?? _autoSaveFileName;
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(content);

      currentFilePath  = filePath;
      lastSavedContent = content;
      return true;
    } catch (e) {
      debugPrint('Error al guardar en Android: $e');
      return false;
    }
  }

  Future<String?> loadAutoSaved() async {
    if (kIsWeb) return null;
    try {
      final dir  = await getAppDirectory();
      final file = File('${dir.path}/$_autoSaveFileName');
      if (!await file.exists()) return null;

      final content    = await file.readAsString();
      currentFilePath  = file.path;
      lastSavedContent = content;
      return content;
    } catch (_) {
      return null;
    }
  }

  /// Abre un selector de archivos (Windows Explorer / Web) y devuelve el contenido.
  Future<String?> pickAndReadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sb', 'txt'],
    );

    if (result != null) {
      if (kIsWeb) {
        // En Web leemos los bytes directamente
        return utf8.decode(result.files.first.bytes!);
      } else {
        // En PC leemos desde el path
        final file = File(result.files.single.path!);
        currentFilePath = file.path;
        final content = await file.readAsString();
        lastSavedContent = content;
        return content;
      }
    }
    return null;
  }

  Future<List<File>> listFiles() async {
    if (kIsWeb) return [];
    try {
      final dir      = await getAppDirectory();
      final entities = dir.listSync();
      return entities
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt') || f.path.endsWith('.sb'))
          .toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
    } catch (e) {
      return [];
    }
  }

  Future<void> share(String content, {String? fileName}) async {
    if (kIsWeb || !Platform.isAndroid) {
      // En PC/Web "Compartir" abre el gestor de archivos para guardar
      await saveToFile(content, customFileName: fileName);
      return;
    }
    
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${fileName ?? 'programa.sb'}');
      await file.writeAsString(content);
      await Share.shareXFiles([XFile(file.path)], subject: 'Programa StemBosque');
    } catch (e) {
      debugPrint('Error al compartir: $e');
    }
  }

  Future<String?> saveCompiled(String content) async {
    if (kIsWeb) return null;
    try {
      final dir  = await getAppDirectory();
      final file = File('${dir.path}/compilado.sb');
      await file.writeAsString(content);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteCompiled() async {
    if (kIsWeb) return;
    try {
      final dir  = await getAppDirectory();
      final file = File('${dir.path}/compilado.sb');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void clear() {
    currentFilePath  = null;
    lastSavedContent = null;
  }

  String formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} '
      '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}
