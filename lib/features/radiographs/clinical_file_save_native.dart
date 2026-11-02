import 'package:flutter/services.dart';

Future<bool?> saveClinicalFile(Uint8List bytes, String name, String mimeType) =>
    const MethodChannel('dental_care/png_files').invokeMethod<bool>(
      'saveFile',
      {'bytes': bytes, 'name': name, 'mimeType': mimeType},
    );
