import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente de la API de Kivox para domiciliarios.
/// Auth simple por token (el mismo del enlace web /d/{token}).
class KivoxApi {
  /// Host de la plataforma. Cambia si usas otro dominio.
  static const String baseUrl = 'https://admin.kivox.co/api/domiciliario';

  final String token;
  KivoxApi(this.token);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  /// Valida el token y devuelve los datos del domiciliario.
  static Future<Map<String, dynamic>> login(String token) async {
    final r = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 20));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200 && data['ok'] == true) return data;
    throw Exception(data['message'] ?? 'No se pudo iniciar sesión.');
  }

  /// Lista los pedidos activos asignados al domiciliario.
  Future<Map<String, dynamic>> pedidos() async {
    final r = await http
        .get(Uri.parse('$baseUrl/pedidos'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 200 && data['ok'] == true) return data;
    throw Exception(data['message'] ?? 'No se pudieron cargar los pedidos.');
  }

  Future<void> iniciarRuta(int pedidoId) async {
    final r = await http
        .post(Uri.parse('$baseUrl/pedidos/$pedidoId/iniciar'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (!(r.statusCode == 200 && data['ok'] == true)) {
      throw Exception(data['message'] ?? 'No se pudo iniciar la ruta.');
    }
  }

  Future<void> entregar(int pedidoId) async {
    final r = await http
        .post(Uri.parse('$baseUrl/pedidos/$pedidoId/entregar'), headers: _headers)
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    if (!(r.statusCode == 200 && data['ok'] == true)) {
      throw Exception(data['message'] ?? 'No se pudo marcar como entregado.');
    }
  }

  Future<void> enviarUbicacion(double lat, double lng) async {
    try {
      await http
          .post(Uri.parse('$baseUrl/ubicacion'),
              headers: _headers, body: jsonEncode({'lat': lat, 'lng': lng}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {/* la ubicación no es crítica */}
  }
}
