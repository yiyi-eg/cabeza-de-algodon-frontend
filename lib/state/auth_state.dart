import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

/// Sesión: el JWT del backend solo trae el username (sub), así que el rol y el
/// id del usuario se resuelven consultando GET /api/usuarios.
class AuthState extends ChangeNotifier {
  final ApiClient api;
  AuthState(this.api) {
    api.onUnauthorized = () => logout();
  }

  String? username, rol;
  int? userId;
  bool loading = true;

  bool get isLogged => api.token != null && rol != null;

  Map<String, dynamic>? _payload(String t) {
    try {
      final p = t.split('.')[1];
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(p)))) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _expired(String t) {
    final exp = _payload(t)?['exp'];
    return exp is! num || DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000).isBefore(DateTime.now());
  }

  Future<void> restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final t = sp.getString('token');
      if (t != null && !_expired(t)) {
        api.token = t;
        await _loadProfile();
      }
    } catch (_) {
      api.token = null;
      rol = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String user, String pass) async {
    final res = await api.post('/api/auth/login', {'username': user.trim(), 'password': pass}, auth: false);
    api.token = res['token'] as String;
    try {
      await _loadProfile();
    } catch (e) {
      api.token = null;
      rethrow;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', api.token!);
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final sub = _payload(api.token!)?['sub'];
    final list = await api.get('/api/usuarios') as List;
    final me = list.cast<Map>().firstWhere((u) => u['username'] == sub, orElse: () => {});
    if (me.isEmpty) throw ApiException('No se encontró tu usuario en el sistema.');
    username = me['username'] as String;
    rol = '${me['rol']}'.toUpperCase();
    userId = (me['idUsuario'] as num).toInt();
  }

  Future<void> logout() async {
    api.token = null;
    rol = null;
    username = null;
    userId = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
    notifyListeners();
  }
}
