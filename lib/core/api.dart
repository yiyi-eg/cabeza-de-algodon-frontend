import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class ApiClient {
  String? token;
  void Function()? onUnauthorized;

  Future<dynamic> get(String p, {bool auth = true}) => _send('GET', p, auth: auth);
  Future<dynamic> post(String p, Object? body, {bool auth = true}) =>
      _send('POST', p, body: body, auth: auth);
  Future<dynamic> put(String p, [Object? body]) => _send('PUT', p, body: body);
  Future<dynamic> delete(String p) => _send('DELETE', p);

  Future<dynamic> _send(String m, String p, {Object? body, bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (auth && token != null) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$baseUrl$p');
    final payload = body == null ? null : jsonEncode(body);
    late http.Response r;
    try {
      final f = switch (m) {
        'POST' => http.post(uri, headers: headers, body: payload),
        'PUT' => http.put(uri, headers: headers, body: payload),
        'DELETE' => http.delete(uri, headers: headers),
        _ => http.get(uri, headers: headers),
      };
      r = await f.timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException(
          'vuelve a intentarlo, servidor encendiendo.');
    }
    final text = utf8.decode(r.bodyBytes);
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = text;
      }
    }
    if (r.statusCode >= 400) {
      if (auth && (r.statusCode == 401 || r.statusCode == 403)) {
        onUnauthorized?.call();
        throw ApiException('Tu sesión expiró. Inicia sesión nuevamente.', r.statusCode);
      }
      throw ApiException(_friendly(data), r.statusCode);
    }
    return data;
  }

  String _friendly(dynamic data) {
    var msg = data is Map ? (data['error'] ?? data['message'] ?? '').toString() : '$data';
    final l = msg.toLowerCase();
    if (l.contains('duplicate key') || l.contains('llave duplicada') || l.contains('unique')) {
      return 'Ya existe un registro con esos datos únicos (por ejemplo, el DPI o el usuario).';
    }
    if (l.contains('not-null') || l.contains('null value') || l.contains('valor nulo')) {
      return 'Falta un dato obligatorio: el servidor recibió un campo vacío.';
    }
    if (l.contains('foreign key') || l.contains('llave foránea') || l.contains('viola la restricción')) {
      return 'No se puede completar: el registro está relacionado con otros datos.';
    }
    if (msg.isEmpty) msg = 'Ocurrió un error inesperado.';
    return msg.length > 220 ? '${msg.substring(0, 220)}…' : msg;
  }
}
