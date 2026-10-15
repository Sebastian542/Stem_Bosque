import 'dart:js_interop';

import 'package:web/web.dart';

/// Descarga un archivo de texto directamente en el navegador.
void downloadWebFile(String content, String fileName) {
  final blob = Blob(
    <BlobPart>[content.toJS].toJS,
    BlobPropertyBag(type: 'text/plain;charset=utf-8'),
  );
  final url = URL.createObjectURL(blob);
  HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..click();
  URL.revokeObjectURL(url);
}
