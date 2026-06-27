import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../main.dart';

class ChatConvScreen extends StatefulWidget {
  final String token;
  final int convId;
  final String nombre;
  const ChatConvScreen({super.key, required this.token, required this.convId, required this.nombre});
  @override
  State<ChatConvScreen> createState() => _ChatConvScreenState();
}

class _ChatConvScreenState extends State<ChatConvScreen> {
  late final MovilApi api = MovilApi(widget.token);
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<dynamic> _msgs = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _telefono;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final d = await api.mensajes(widget.convId);
      if (!mounted) return;
      final nuevos = d['mensajes'] as List;
      final crecio = nuevos.length != _msgs.length;
      setState(() { _msgs = nuevos; _telefono = d['telefono']?.toString(); _cargando = false; });
      if (crecio) _alFinal();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _enviar() async {
    final txt = _input.text.trim();
    if (txt.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final m = await api.enviar(widget.convId, txt);
      _input.clear();
      setState(() => _msgs = [..._msgs, m]);
      _alFinal();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red, duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.nombre, style: const TextStyle(fontSize: 16)),
          if (_telefono != null) Text(_telefono!, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) => _burbuja(_msgs[i] as Map<String, dynamic>),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1, maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true, fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                CircleAvatar(
                  radius: 24, backgroundColor: kBrand,
                  child: _enviando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _enviar),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _burbuja(Map<String, dynamic> m) {
    final mio = m['mio'] == true;
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mio ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3)],
        ),
        child: Text((m['contenido'] ?? '').toString(), style: const TextStyle(fontSize: 14.5)),
      ),
    );
  }
}
