// Standalone Chrome regression check; compile with `dart compile js`.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import '../../lib/features/radiographs/local_png_files_web.dart';

Future<void> main() async {
  try {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZ1cAAAAASUVORK5CYII=',
    );
    final result = await readPngFile(
      html.File([png], 'radiografia.png', {'type': 'image/png'}),
    );
    final bytes = result['bytes'] as Uint8List;
    if (result['name'] != 'radiografia.png' ||
        bytes.length != png.length ||
        !List.generate(png.length, (i) => bytes[i] == png[i]).every((v) => v)) {
      throw StateError('Los bytes leidos no coinciden con el PNG original.');
    }
    html.document.body!.text = 'PASS: Chrome reads PNG bytes and filename.';
  } catch (error) {
    html.document.body!.text = 'FAIL: $error';
  }
}
