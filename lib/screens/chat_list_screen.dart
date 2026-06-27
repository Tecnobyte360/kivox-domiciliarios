import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../main.dart';
import 'chat_conv_screen.dart';

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
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => _cargar()),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _busqueda,
              onChanged: (_) => _cargar(silencioso: true),
              decoration: InputDecoration(
                hintText: 'Buscar cliente o teléfono',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.separated(
                      itemCount: _convs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _convs[i] as Map<String, dynamic>;
                        final noLeidos = (c['no_leidos'] ?? 0) as int;
                        final nombre = (c['nombre'] ?? 'Cliente').toString();
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: kBrand.withOpacity(0.15),
                            child: Text(_iniciales(nombre), style: const TextStyle(color: kBrand, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text((c['ultimo'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: noLeidos > 0
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
                                  child: Text('$noLeidos', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              : const Icon(Icons.chevron_right, color: Colors.black26),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChatConvScreen(token: widget.token, convId: c['id'] as int, nombre: nombre),
                          )).then((_) => _cargar(silencioso: true)),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _iniciales(String n) {
    final parts = n.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
