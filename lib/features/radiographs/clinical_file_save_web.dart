// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool?> saveClinicalFile(
  Uint8List bytes,
  String name,
  String mimeType,
) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
  html.AnchorElement(href: url)
    ..download = name
    ..click();
  await Future<void>.delayed(const Duration(seconds: 1));
  html.Url.revokeObjectUrl(url);
  return true;
}
