import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import 'chat_conv_screen.dart'; // waTeal, ChatConvScreen

const waUnread = Color(0xFF25D366);

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
  String _filtro = 'todos'; // todos | no_leidos
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
      setState(() { _convs = c; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  List<dynamic> get _filtradas {
    if (_filtro == 'no_leidos') return _convs.where((c) => ((c['no_leidos'] ?? 0) as int) > 0 || c['no_leida'] == true).toList();
    if (_filtro == 'favoritos') return _convs.where((c) => c['favorito'] == true).toList();
    return _convs;
  }

  Future<void> _accionesConv(Map<String, dynamic> c) async {
    final fav = c['favorito'] == true;
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [
      Padding(padding: const EdgeInsets.all(14), child: Text((c['nombre'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ListTile(
        leading: Icon(fav ? Icons.star : Icons.star_border, color: const Color(0xFFF5B400)),
        title: Text(fav ? 'Quitar de favoritos' : 'Marcar como favorito'),
        onTap: () async { Navigator.pop(context); try { await api.favorito(c['id'] as int, !fav); } catch (_) {} _cargar(silencioso: true); },
      ),
      ListTile(
        leading: const Icon(Icons.mark_chat_unread, color: Color(0xFF25D366)),
        title: const Text('Marcar como no leído'),
        onTap: () async { Navigator.pop(context); try { await api.marcarNoLeida(c['id'] as int, true); } catch (_) {} _cargar(silencioso: true); },
      ),
      ListTile(
        leading: const Icon(Icons.done_all, color: Colors.black54),
        title: const Text('Marcar como leído'),
        onTap: () async { Navigator.pop(context); try { await api.marcarNoLeida(c['id'] as int, false); } catch (_) {} _cargar(silencioso: true); },
      ),
    ])));
  }

  int get _totalNoLeidos => _convs.fold(0, (s, c) => s + ((c['no_leidos'] ?? 0) as int));

  String _hora(dynamic iso) {
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      final ahora = DateTime.now();
      if (d.year == ahora.year && d.month == ahora.month && d.day == ahora.day) {
        final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
        return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
      }
      const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
      if (ahora.difference(d).inDays < 7) return dias[d.weekday - 1];
      return '${d.day}/${d.month}/${d.year % 100}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text('Chats', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              )),
              // Buscador
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: _busqueda,
                    onChanged: (_) => _cargar(silencioso: true),
                    decoration: const InputDecoration(
                      hintText: 'Buscar',
                      prefixIcon: Icon(Icons.search, color: Colors.black45),
                      border: InputBorder.none, isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              )),
              // Chips
              SliverToBoxAdapter(child: SizedBox(height: 40, child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _chip('Todos', 'todos'),
                  const SizedBox(width: 8),
                  _chip('No leídos${_totalNoLeidos > 0 ? '  $_totalNoLeidos' : ''}', 'no_leidos'),
                  const SizedBox(width: 8),
                  _chip('Favoritos', 'favoritos'),
                ],
              ))),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              if (_cargando)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_filtradas.isEmpty)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Sin conversaciones', style: TextStyle(color: Colors.black45))))
              else
                SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) => _item(_filtradas[i] as Map<String, dynamic>),
                  childCount: _filtradas.length,
                )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String val) {
    final sel = _filtro == val;
    return GestureDetector(
      onTap: () => setState(() => _filtro = val),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFD8F5D3) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? const Color(0xFF25D366) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: sel ? const Color(0xFF1A7F3C) : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13.5)),
      ),
    );
  }

  Widget _item(Map<String, dynamic> c) {
    final noLeidos = (c['no_leidos'] ?? 0) as int;
    final noLeida = c['no_leida'] == true;
    final fav = c['favorito'] == true;
    final nombre = (c['nombre'] ?? 'Cliente').toString();
    final mio = c['ultimo_mio'] == true;
    final ultimo = (c['ultimo'] ?? '').toString();
    final badge = noLeidos > 0 ? noLeidos : (noLeida ? 1 : 0);

    return InkWell(
      onLongPress: () => _accionesConv(c),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatConvScreen(token: widget.token, convId: c['id'] as int, nombre: nombre),
      )).then((_) => _cargar(silencioso: true)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: const Color(0xFFB9E0D0),
            child: Text(_ini(nombre), style: const TextStyle(color: Color(0xFF075E54), fontWeight: FontWeight.bold, fontSize: 17))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5))),
              Text(_hora(c['ultimo_at']), style: TextStyle(fontSize: 12, color: badge > 0 ? waUnread : Colors.black45)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              if (mio) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.done_all, size: 16, color: Color(0xFF53BDEB))),
              Expanded(child: Text(ultimo, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: badge > 0 ? FontWeight.w600 : FontWeight.normal))),
              if (fav) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star, size: 16, color: Color(0xFFF5B400))),
              if (noLeidos > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: waUnread, borderRadius: BorderRadius.circular(12)),
                  constraints: const BoxConstraints(minWidth: 20),
                  child: Text('$noLeidos', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              else if (noLeida)
                Container(margin: const EdgeInsets.only(left: 6), width: 12, height: 12, decoration: const BoxDecoration(color: waUnread, shape: BoxShape.circle)),
            ]),
          ])),
        ]),
      ),
    );
  }

  String _ini(String n) {
    final p = n.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'C';
    return (p.length == 1 ? p[0].substring(0, 1) : p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
  }
}
