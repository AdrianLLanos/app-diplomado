import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ClinicApiException implements Exception {
  const ClinicApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiFile {
  const ApiFile(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// Uses the same API, Bearer token and company header as the Angular client.
/// Database passwords and server keys never belong in this client.
class ClinicApi {
  ClinicApi({AppConfig config = const AppConfig(), http.Client? client})
    : _config = config,
      _client = client ?? http.Client();

  static ClinicApi instance = ClinicApi();
  final AppConfig _config;
  final http.Client _client;
  String? _token;
  String? _companyId;
  String? userId;
  void Function()? onSessionExpired;
  int _sessionVersion = 0;

  Uri _uri(String path, Map<String, String>? query) => Uri.parse(
    '${_config.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/$path',
  ).replace(queryParameters: query);

  void clearSession() {
    _sessionVersion++;
    _token = null;
    _companyId = null;
    userId = null;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    clearSession();
    final login = await request(
      'POST',
      'login',
      body: {'correo': email, 'contrasena': password},
      authenticated: false,
    );
    _token = login['token'] as String?;
    if (_token == null || _token!.isEmpty) {
      throw const ClinicApiException(
        'El servidor no devolvió una sesión válida.',
      );
    }
    try {
      final session = await request('GET', 'session');
      final user = Map<String, dynamic>.from(session['user'] as Map);
      _companyId = session['companyId'].toString();
      userId = user['id'].toString();
      return user;
    } catch (_) {
      clearSession();
      rethrow;
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    bool followRedirects = true,
  }) async {
    if (!_config.isConfigured) {
      throw const ClinicApiException(
        'Configura una API_BASE_URL HTTPS válida.',
      );
    }
    if (authenticated && _token == null) {
      throw const ClinicApiException('Inicia sesión para continuar.', 401);
    }
    final version = _sessionVersion;
    final request = http.Request(method, _uri(path, query))
      ..followRedirects = followRedirects
      ..headers['Accept'] = 'application/json';
    if (authenticated) {
      request.headers['Authorization'] = 'Bearer $_token';
      if (_companyId != null) request.headers['X-Company-ID'] = _companyId!;
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 45));
      if (authenticated && version != _sessionVersion) {
        throw const ClinicApiException(
          'La sesión cambió. Vuelve a iniciar sesión.',
          401,
        );
      }
      if (response.statusCode == 401 && authenticated) {
        clearSession();
        onSessionExpired?.call();
      }
      if (response.statusCode >= 400) {
        String? message;
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map && data['message'] is String)
            message = data['message'];
        } catch (_) {
          /* Non-JSON proxy error. */
        }
        throw ClinicApiException(
          message ??
              'No se pudo completar la solicitud (${response.statusCode}).',
          response.statusCode,
        );
      }
      return response;
    } on TimeoutException {
      throw const ClinicApiException(
        'El servidor tardó demasiado. Intenta nuevamente.',
      );
    } on http.ClientException {
      throw const ClinicApiException(
        'No se pudo conectar con el sistema web. Comprueba tu conexión.',
      );
    }
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    final response = await _send(
      method,
      path,
      query: query,
      body: body,
      authenticated: authenticated,
    );
    try {
      return response.bodyBytes.isEmpty
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ClinicApiException(
        'La dirección configurada no devolvió una respuesta de la API.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> all(String resource) async {
    final rows = <Map<String, dynamic>>[];
    var page = 0;
    while (true) {
      final data = await request(
        'GET',
        resource,
        query: {'page': '$page', 'size': '100'},
      );
      final batch = (data['rows'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      rows.addAll(batch);
      if (batch.isEmpty || rows.length >= (data['total'] as num).toInt())
        return rows;
      page++;
    }
  }

  Future<void> save(
    String resource,
    String id,
    Map<String, dynamic> values,
  ) async {
    await request(
      id.isEmpty ? 'POST' : 'PUT',
      id.isEmpty ? resource : '$resource/$id',
      body: values,
    );
  }

  Future<void> delete(String resource, String id) async {
    await request('DELETE', '$resource/$id');
  }

  Future<ApiFile> file(String path) async {
    // Browsers cannot expose a redirect when followRedirects is false.
    // Ask for a temporary link as JSON; older native clients keep using 302.
    var response = await _send(
      'GET',
      path,
      query: {'delivery': 'json'},
      followRedirects: false,
    );
    final isLinkResponse =
        response.statusCode == 200 &&
        (response.headers['content-type'] ?? '').split(';').first ==
            'application/json';
    if (isLinkResponse ||
        [301, 302, 303, 307, 308].contains(response.statusCode)) {
      String? location;
      if (isLinkResponse) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map && data['signedUrl'] is String) {
            location = data['signedUrl'] as String;
          }
        } on FormatException {
          // Invalid metadata is rejected below before making any download.
        }
      } else {
        location = response.headers['location'];
      }
      final uri = location == null ? null : Uri.tryParse(location);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const ClinicApiException(
          'El servidor no devolvió un enlace de archivo válido.',
        );
      }
      // Signed Storage URL: never forward the API's Bearer token to Storage.
      try {
        response = await _client.get(uri).timeout(const Duration(seconds: 60));
      } on TimeoutException {
        throw const ClinicApiException(
          'La descarga tardó demasiado. Intenta nuevamente.',
        );
      } on http.ClientException {
        throw const ClinicApiException('No se pudo descargar la radiografía.');
      }
    }
    if (response.statusCode != 200) {
      throw const ClinicApiException('No se pudo descargar la radiografía.');
    }
    final mime = (response.headers['content-type'] ?? '').split(';').first;
    if (![
      'application/pdf',
      'image/png',
      'image/jpeg',
      'image/webp',
    ].contains(mime)) {
      throw const ClinicApiException(
        'El archivo no tiene un formato compatible.',
      );
    }
    return ApiFile(response.bodyBytes, mime);
  }
}
