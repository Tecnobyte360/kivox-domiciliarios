import 'dart:convert';
import 'package:http/http.dart' as http;

const String kHost = 'https://admin.kivox.co';

/// ───────── API del domiciliario (portal de entregas, token por domiciliario)
class KivoxApi {
  static const String baseUrl = '$kHost/api/domiciliario';
  final String token;
  KivoxApi(this.token);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> pedidos() async {
    final r = await http.get(Uri.parse('$baseUrl/pedidos'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200 && data['ok'] == true) return data;
    throw Exception(data['message'] ?? 'No se pudieron cargar los pedidos.');
  }

  Future<void> iniciarRuta(int pedidoId) async {
    final r = await http.post(Uri.parse('$baseUrl/pedidos/$pedidoId/iniciar'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final d = jsonDecode(r.body);
    if (!(r.statusCode == 200 && d['ok'] == true)) throw Exception(d['message'] ?? 'No se pudo iniciar la ruta.');
  }

  Future<void> entregar(int pedidoId) async {
    final r = await http.post(Uri.parse('$baseUrl/pedidos/$pedidoId/entregar'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final d = jsonDecode(r.body);
    if (!(r.statusCode == 200 && d['ok'] == true)) throw Exception(d['message'] ?? 'No se pudo marcar como entregado.');
  }

  Future<void> enviarUbicacion(double lat, double lng) async {
    try {
      await http.post(Uri.parse('$baseUrl/ubicacion'),
          headers: _headers, body: jsonEncode({'lat': lat, 'lng': lng}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }
}

/// ───────── API de la app móvil (usuarios con roles/permisos: chat, etc.)
class MovilApi {
  static const String base = '$kHost/api/movil';
  final String token; // Sanctum
  MovilApi(this.token);

  Map<String, String> get _h => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// Login con usuario + clave. Devuelve { token, user{permisos, ...} }.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await http.post(Uri.parse('$base/login'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}))
        .timeout(const Duration(seconds: 20));
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200 && d['ok'] == true) return d;
    throw Exception(d['message'] ?? 'No se pudo iniciar sesión.');
  }

  Future<List<dynamic>> conversaciones({String q = ''}) async {
    final r = await http.get(Uri.parse('$base/chat/conversaciones?q=${Uri.encodeQueryComponent(q)}'), headers: _h)
        .timeout(const Duration(seconds: 20));
    final d = jsonDecode(r.body);
    if (r.statusCode == 200 && d['ok'] == true) return d['conversaciones'] as List;
    throw Exception(d['message'] ?? 'No se pudieron cargar las conversaciones.');
  }

  Future<Map<String, dynamic>> mensajes(int id) async {
    final r = await http.get(Uri.parse('$base/chat/conversaciones/$id/mensajes'), headers: _h)
        .timeout(const Duration(seconds: 20));
    final d = jsonDecode(r.body);
    if (r.statusCode == 200 && d['ok'] == true) return d as Map<String, dynamic>;
    throw Exception(d['message'] ?? 'No se pudieron cargar los mensajes.');
  }

  Future<Map<String, dynamic>> enviar(int id, String texto) async {
    final r = await http.post(Uri.parse('$base/chat/conversaciones/$id/enviar'), headers: _h,
        body: jsonEncode({'texto': texto})).timeout(const Duration(seconds: 25));
    final d = jsonDecode(r.body);
    if (r.statusCode == 200 && d['ok'] == true) return d['mensaje'] as Map<String, dynamic>;
    throw Exception(d['message'] ?? 'No se pudo enviar el mensaje.');
  }
}
