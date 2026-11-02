// The browser implementation is isolated from the Android build.
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<Map<String, dynamic>?> pickPng() async {
  final input = html.FileUploadInputElement()..accept = '.png,image/png';
  final selected = Completer<html.File?>();
  final changed = input.onChange.listen((_) {
    if (!selected.isCompleted) {
      final files = input.files;
      selected.complete(files == null || files.isEmpty ? null : files.first);
    }
  });
  void cancel(html.Event _) {
    if (!selected.isCompleted) selected.complete(null);
  }

  input.addEventListener('cancel', cancel);
  input.style.display = 'none';
  html.document.body!.append(input);
  Timer? focusCheck;
  final focused = html.window.onFocus.listen((_) {
    focusCheck?.cancel();
    focusCheck = Timer(const Duration(milliseconds: 500), () {
      if (!selected.isCompleted) {
        final files = input.files;
        selected.complete(files == null || files.isEmpty ? null : files.first);
      }
    });
  });
  try {
    input.click();
    final file = await selected.future;
    if (file == null) return null;
    return await readPngFile(file);
  } finally {
    focusCheck?.cancel();
    await focused.cancel();
    await changed.cancel();
    input.removeEventListener('cancel', cancel);
    input.remove();
  }
}

Future<Map<String, dynamic>> readPngFile(html.File file) async {
  if (file.size > 50 * 1024 * 1024) {
    throw const FormatException('La imagen supera 50 MB.');
  }
  final reader = html.FileReader();
  final loaded = Completer<Uint8List>();
  final load = reader.onLoad.listen((_) {
    if (loaded.isCompleted) return;
    try {
      final result = reader.result;
      // dart:html converts the browser ArrayBuffer into Uint8List already.
      if (result is Uint8List) {
        loaded.complete(result);
      } else if (result is ByteBuffer) {
        loaded.complete(result.asUint8List());
      } else {
        throw const FormatException('No se pudieron leer los bytes del PNG.');
      }
    } catch (error, stack) {
      loaded.completeError(error, stack);
    }
  });
  void fail(html.ProgressEvent _) {
    if (!loaded.isCompleted) {
      loaded.completeError(const FormatException('No se pudo leer el PNG.'));
    }
  }

  final error = reader.onError.listen(fail);
  final aborted = reader.onAbort.listen(fail);
  try {
    reader.readAsArrayBuffer(file);
    final bytes = await loaded.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const FormatException(
        'La lectura tardo demasiado. Vuelve a seleccionar el PNG.',
      ),
    );
    return {'name': file.name, 'bytes': bytes};
  } finally {
    await load.cancel();
    await error.cancel();
    await aborted.cancel();
    if (reader.readyState == html.FileReader.LOADING) reader.abort();
  }
}

Future<bool?> savePng(Uint8List bytes, String name) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'image/png'));
  final link = html.AnchorElement(href: url)
    ..download = name
    ..style.display = 'none';
  html.document.body!.append(link);
  link.click();
  link.remove();
  // Allow Chrome to begin reading the blob before releasing its URL.
  Timer(const Duration(seconds: 10), () => html.Url.revokeObjectUrl(url));
  return true;
}
