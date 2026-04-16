// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

/// Procesa la descarga de un archivo directamente en el navegador
void downloadWebFile(String content, String fileName) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
    
  html.Url.revokeObjectUrl(url);
}
