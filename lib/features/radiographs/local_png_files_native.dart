import 'dart:typed_data';
import 'package:flutter/services.dart';

const _files = MethodChannel('dental_care/png_files');

Future<Map<String, dynamic>?> pickPng() =>
    _files.invokeMapMethod<String, dynamic>('pickPng');

Future<bool?> savePng(Uint8List bytes, String name) =>
    _files.invokeMethod<bool>('savePng', {'bytes': bytes, 'name': name});
