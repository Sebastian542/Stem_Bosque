import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileManager {
  static const String _autoSaveFileName = 'stembosque_current_program.txt';

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

  Future<bool> saveToFile(String content, {String? customFileName}) async {
    try {
      final dir      = await getAppDirectory();
      final fileName = customFileName ?? _autoSaveFileName;
      final filePath = '${dir.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(content);

      if (!await file.exists()) throw Exception('Archivo no creado');
      if (await file.readAsString() != content) {
        throw Exception('Verificación fallida');
      }

      currentFilePath  = filePath;
      lastSavedContent = content;
      return true;
    } catch (e) {
      debugPrint('Error al guardar: $e');
      return false;
    }
  }

  Future<String?> loadAutoSaved() async {
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

  Future<List<File>> listFiles() async {
    final dir      = await getAppDirectory();
    final entities = dir.listSync();
    return entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt') || f.path.endsWith('.sb'))
        .toList()
      ..sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
  }

  Future<void> share(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Programa StemBosque',
    );
  }

  void clear() {
    currentFilePath  = null;
    lastSavedContent = null;
  }

  String formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} '
          '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}