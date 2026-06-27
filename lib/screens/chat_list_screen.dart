import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import 'chat_conv_screen.dart'; // waGreen, waTeal, ChatConvScreen

class ChatListScreen extends StatefulWidget {
  final String token;
  const ChatListScreen({super.key, required this.token});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late final MovilApi api = MovilApi(widget.token);
  final _busqueda = TextEditingController();
  List<dynamic> _convs = [];
  bool _cargando = true;
  bool _buscando = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final c = await api.conversaciones(q: _busqueda.text.trim());
      if (!mounted) return;
      setState(() { _convs = c; _error = null; _cargando = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _cargando = false; });
    }
  }

  String _hora(dynamic iso) {
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      final ahora = DateTime.now();
      if (d.year == ahora.year && d.month == ahora.month && d.day == ahora.day) {
        final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
        return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'a.m.' : 'p.m.'}';
      }
      return '${d.day}/${d.month}/${d.year % 100}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: waGreen,
        title: _buscando
            ? TextField(
                controller: _busqueda, autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                onChanged: (_) => _cargar(silencioso: true),
                decoration: const InputDecoration(hintText: 'Buscar…', hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
              )
            : const Text('Chats'),
        actions: [
          IconButton(
            icon: Icon(_buscando ? Icons.close : Icons.search),
            onPressed: () => setState(() { _buscando = !_buscando; if (!_buscando) { _busqueda.clear(); _cargar(silencioso: true); } }),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _convs.isEmpty
                  ? ListView(children: [
                      if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                      const SizedBox(height: 120),
                      const Center(child: Text('Sin conversaciones', style: TextStyle(color: Colors.black45))),
                    ])
                  : ListView.separated(
                      itemCount: _convs.length,
                      separatorBuilder: (_, __) => const Padding(padding: EdgeInsets.only(left: 82), child: Divider(height: 1)),
                      itemBuilder: (_, i) {
                        final c = _convs[i] as Map<String, dynamic>;
                        final noLeidos = (c['no_leidos'] ?? 0) as int;
                        final nombre = (c['nombre'] ?? 'Cliente').toString();
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(radius: 27, backgroundColor: const Color(0xFFB9E0D0),
                            child: Text(_ini(nombre), style: const TextStyle(color: waGreen, fontWeight: FontWeight.bold, fontSize: 16))),
                          title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          subtitle: Text((c['ultimo'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54)),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_hora(c['ultimo_at']), style: TextStyle(fontSize: 11.5, color: noLeidos > 0 ? waTeal : Colors.black45, fontWeight: noLeidos > 0 ? FontWeight.bold : FontWeight.normal)),
                            const SizedBox(height: 5),
                            if (noLeidos > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(12)),
                                constraints: const BoxConstraints(minWidth: 20),
                                child: Text('$noLeidos', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                              )
                            else
                              const SizedBox(height: 18),
                          ]),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatConvScreen(token: widget.token, convId: c['id'] as int, nombre: nombre),
                          )).then((_) => _cargar(silencioso: true)),
                        );
                      },
                    ),
            ),
    );
  }

  String _ini(String n) {
    final p = n.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'C';
    return (p.length == 1 ? p[0].substring(0, 1) : p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
  }
}
