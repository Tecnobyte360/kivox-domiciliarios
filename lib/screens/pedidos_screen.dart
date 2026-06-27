import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../main.dart';
import 'login_screen.dart';

class PedidosScreen extends StatefulWidget {
  final String token;
  const PedidosScreen({super.key, required this.token});
  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  late final KivoxApi api = KivoxApi(widget.token);
  bool _cargando = true;
  String? _error;
  Map<String, dynamic> _data = {};
  Timer? _refrescoTimer;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _refrescoTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar(silencioso: true));
    _gpsTimer = Timer.periodic(const Duration(seconds: 45), (_) => _enviarUbicacion());
    _enviarUbicacion();
  }

  @override
  void dispose() {
    _refrescoTimer?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final d = await api.pedidos();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _cargando = false;
      });
    }
  }

  Future<void> _enviarUbicacion() async {
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12));
      await api.enviarUbicacion(pos.latitude, pos.longitude);
    } catch (_) {/* silencioso */}
  }

  Future<void> _confirmar({
    required String titulo,
    required String mensaje,
    required String botonOk,
    required Color color,
    required Future<void> Function() accion,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(botonOk),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await accion();
      await _cargar(silencioso: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Listo'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _abrirMapa(num? lat, num? lng, String? dir) async {
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    } else if (dir != null && dir.isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(dir)}');
    } else {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _llamar(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    await launchUrl(Uri.parse('tel:$tel'));
  }

  Future<void> _salir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final domi = _data['domiciliario'] as Map<String, dynamic>?;
    final pedidos = (_data['pedidos'] as List?) ?? [];
    final pendientes = _data['pendientes'] ?? pedidos.length;
    final entregados = _data['entregados_hoy'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pedidos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _cargar()),
          IconButton(icon: const Icon(Icons.logout), onPressed: _salir),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _encabezado(domi, pendientes, entregados),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (pedidos.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(children: [
                          Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
                          SizedBox(height: 10),
                          Text('Sin pedidos pendientes', style: TextStyle(color: Colors.black54)),
                        ]),
                      ),
                    ),
                  ...pedidos.map((p) => _tarjetaPedido(p as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }

  Widget _encabezado(Map<String, dynamic>? domi, dynamic pend, dynamic entr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kBrand, Color(0xFF6D28D9)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¡Hola ${domi?['nombre'] ?? ''}!',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          if (domi?['vehiculo'] != null || domi?['placa'] != null)
            Text('${domi?['vehiculo'] ?? ''}  ·  ${domi?['placa'] ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          Row(children: [
            _kpi('$pend', 'PENDIENTES'),
            const SizedBox(width: 10),
            _kpi('$entr', 'ENTREGADOS HOY'),
          ]),
        ],
      ),
    );
  }

  Widget _kpi(String n, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text(n, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _tarjetaPedido(Map<String, dynamic> p) {
    final estado = p['estado'] as String? ?? '';
    final enCamino = estado == 'repartidor_en_camino';
    final total = (p['total'] ?? 0);
    final dir = [p['direccion'], p['barrio'], p['ciudad']]
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Pedido #${p['id']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _chipEstado(estado, enCamino),
            ],
          ),
          const SizedBox(height: 2),
          Text(p['cliente'] ?? 'Cliente', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
            const SizedBox(width: 4),
            Expanded(child: Text(dir.isEmpty ? 'Sin dirección' : dir, style: const TextStyle(fontSize: 13))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.phone, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            Text(p['telefono'] ?? '—', style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text('\$${_fmt(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          // Código de entrega
          if (enCamino && (p['token_entrega'] != null))
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFCD34D)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.vpn_key, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Código del cliente: '),
                    TextSpan(
                        text: '${p['token_entrega']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ])),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _abrirMapa(p['lat'], p['lng'], dir),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Ir'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _llamar(p['telefono']),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Llamar'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: enCamino
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _confirmar(
                      titulo: '✅ ¿Confirmar entrega?',
                      mensaje: 'Pedido #${p['id']} — confirma que ya lo entregaste.',
                      botonOk: 'Sí, entregado',
                      color: Colors.green,
                      accion: () => api.entregar(p['id']),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Entregado'),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kBrand),
                    onPressed: () => _confirmar(
                      titulo: '🛵 ¿Iniciar ruta?',
                      mensaje: 'Pedido #${p['id']} — se le avisará al cliente que va en camino.',
                      botonOk: 'Sí, iniciar',
                      color: kBrand,
                      accion: () => api.iniciarRuta(p['id']),
                    ),
                    icon: const Icon(Icons.motorcycle),
                    label: const Text('Iniciar ruta'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chipEstado(String estado, bool enCamino) {
    final txt = enCamino ? 'En camino' : (estado == 'en_preparacion' ? 'En preparación' : estado);
    final color = enCamino ? kBrand : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(txt, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  String _fmt(dynamic n) {
    final v = (n is num) ? n.toInt() : int.tryParse('$n') ?? 0;
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }
}
