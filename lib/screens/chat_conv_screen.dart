import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final d = await api.mensajes(widget.convId);
      if (!mounted) return;
      final nuevos = d['mensajes'] as List;
      final crecio = nuevos.length != _msgs.length;
      setState(() { _msgs = nuevos; _telefono = d['telefono']?.toString(); _cargando = false; });
      if (crecio) _alFinal();
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _err(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
  }

  Future<void> _enviar() async {
    final txt = _input.text.trim();
    if (txt.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final m = await api.enviar(widget.convId, txt);
      _input.clear();
      setState(() => _msgs = [..._msgs, m]); _alFinal();
    } catch (e) { _err(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _enviando = false); }
  }

  Future<void> _foto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final name = x.name.isNotEmpty ? x.name : 'foto.jpg';
      final mime = name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      setState(() => _enviando = true);
      final m = await api.enviarMedia(widget.convId, dataUrl, 'image', name);
      setState(() => _msgs = [..._msgs, m]); _alFinal();
    } catch (e) { _err(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _enviando = false); }
  }

  void _menuAdjuntar() {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Wrap(children: [
        ListTile(leading: const Icon(Icons.photo_library, color: kBrand), title: const Text('Foto de la galería'), onTap: () { Navigator.pop(context); _foto(ImageSource.gallery); }),
        ListTile(leading: const Icon(Icons.photo_camera, color: kBrand), title: const Text('Tomar foto'), onTap: () { Navigator.pop(context); _foto(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.dashboard_customize, color: kBrand), title: const Text('Enviar plantilla'), onTap: () { Navigator.pop(context); _plantillas(); }),
      ]),
    ));
  }

  Future<void> _plantillas() async {
    try {
      final ps = await api.plantillas();
      if (!mounted) return;
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, ctrl) => ListView(controller: ctrl, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('Plantillas aprobadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ...ps.map((p) => ListTile(
            title: Text((p['nombre'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text((p['body_preview'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: (p['num_variables'] ?? 0) > 0 ? Chip(label: Text('${p['num_variables']} var')) : null,
            onTap: () { Navigator.pop(context); _usarPlantilla(p as Map<String, dynamic>); },
          )),
        ]),
      ));
    } catch (e) { _err(e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _usarPlantilla(Map<String, dynamic> p) async {
    final n = (p['num_variables'] ?? 0) as int;
    List<String> vars = [];
    if (n > 0) {
      final ctrls = List.generate(n, (_) => TextEditingController());
      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: Text('Variables de ${p['nombre']}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < n; i++) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: ctrls[i], decoration: InputDecoration(labelText: 'Variable {{${i + 1}}}', border: const OutlineInputBorder()))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kBrand), onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
        ],
      ));
      if (ok != true) return;
      vars = ctrls.map((c) => c.text).toList();
    }
    try {
      await api.enviarPlantilla(widget.convId, (p['nombre']).toString(), (p['idioma'] ?? 'es').toString(), vars);
      await _cargar(silencioso: true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Plantilla enviada'), backgroundColor: Colors.green));
    } catch (e) { _err(e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _abrir(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
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
      body: Column(children: [
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _msgs.length,
                  itemBuilder: (_, i) => _burbuja(_msgs[i] as Map<String, dynamic>)),
        ),
        SafeArea(top: false, child: Container(
          padding: const EdgeInsets.all(8), color: Colors.white,
          child: Row(children: [
            IconButton(icon: const Icon(Icons.add_circle, color: kBrand, size: 30), onPressed: _enviando ? null : _menuAdjuntar),
            Expanded(child: TextField(
              controller: _input, minLines: 1, maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true, fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            )),
            const SizedBox(width: 6),
            CircleAvatar(radius: 24, backgroundColor: kBrand,
              child: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _enviar)),
          ]),
        )),
      ]),
    );
  }

  Widget _burbuja(Map<String, dynamic> m) {
    final mio = m['mio'] == true;
    final tipo = (m['tipo'] ?? 'text').toString();
    final media = m['media_url']?.toString();
    final texto = (m['contenido'] ?? '').toString();

    Widget contenido;
    if (media != null && media.isNotEmpty && tipo == 'image') {
      contenido = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: GestureDetector(
          onTap: () => _abrir(media),
          child: Image.network(media, width: 220, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(width: 220, height: 120, child: Icon(Icons.broken_image))),
        )),
        if (texto.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(texto)),
      ]);
    } else if (media != null && media.isNotEmpty) {
      contenido = InkWell(onTap: () => _abrir(media), child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(tipo == 'audio' ? Icons.play_circle : Icons.insert_drive_file, color: kBrand),
        const SizedBox(width: 8),
        Flexible(child: Text(texto.isNotEmpty ? texto : (tipo == 'audio' ? 'Audio' : 'Documento'),
          style: const TextStyle(decoration: TextDecoration.underline))),
      ]));
    } else {
      contenido = Text(texto, style: const TextStyle(fontSize: 14.5));
    }

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
        child: contenido,
      ),
    );
  }
}
