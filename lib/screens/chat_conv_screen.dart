import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../main.dart';

// Paleta WhatsApp
const waGreen = Color(0xFF075E54);
const waTeal = Color(0xFF128C7E);
const waBubbleOut = Color(0xFFDCF8C6);
const waBg = Color(0xFFECE5DD);

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
  bool _hayTexto = false;
  String? _telefono;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final t = _input.text.trim().isNotEmpty;
      if (t != _hayTexto) setState(() => _hayTexto = t);
    });
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

  String _hora(dynamic iso) {
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m ${d.hour < 12 ? 'a.m.' : 'p.m.'}';
    } catch (_) { return ''; }
  }

  Future<void> _enviar() async {
    final txt = _input.text.trim();
    if (txt.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final m = await api.enviar(widget.convId, txt);
      _input.clear();
      setState(() { _msgs = [..._msgs, m]; _hayTexto = false; }); _alFinal();
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
        ListTile(leading: const Icon(Icons.photo_library, color: waTeal), title: const Text('Foto de la galería'), onTap: () { Navigator.pop(context); _foto(ImageSource.gallery); }),
        ListTile(leading: const Icon(Icons.photo_camera, color: waTeal), title: const Text('Cámara'), onTap: () { Navigator.pop(context); _foto(ImageSource.camera); }),
        ListTile(leading: const Icon(Icons.bolt, color: waTeal), title: const Text('Respuesta rápida'), onTap: () { Navigator.pop(context); _respuestasRapidas(); }),
        ListTile(leading: const Icon(Icons.dashboard_customize, color: waTeal), title: const Text('Plantilla'), onTap: () { Navigator.pop(context); _plantillas(); }),
      ]),
    ));
  }

  Future<void> _respuestasRapidas() async {
    try {
      final rs = await api.respuestasRapidas();
      if (!mounted) return;
      if (rs.isEmpty) { _err('No tienes respuestas rápidas configuradas.'); return; }
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.5, maxChildSize: 0.9,
        builder: (_, ctrl) => ListView(controller: ctrl, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('Respuestas rápidas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ...rs.map((q) => ListTile(
            leading: const Icon(Icons.bolt, color: waTeal),
            title: Text((q['atajo'] ?? 'Respuesta').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text((q['texto'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () { Navigator.pop(context); _input.text = (q['texto'] ?? '').toString(); },
          )),
        ]),
      ));
    } catch (e) { _err(e.toString().replaceFirst('Exception: ', '')); }
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
          FilledButton(style: FilledButton.styleFrom(backgroundColor: waTeal), onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
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

  void _menuReaccion(Map<String, dynamic> m) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        ...emojis.map((e) => GestureDetector(
          onTap: () { Navigator.pop(context); _reaccionar(m, m['reaccion'] == e ? '' : e); },
          child: Text(e, style: const TextStyle(fontSize: 30)),
        )),
        GestureDetector(onTap: () { Navigator.pop(context); _reaccionar(m, ''); },
          child: const Icon(Icons.do_not_disturb_alt, size: 28, color: Colors.black38)),
      ]),
    )));
  }

  Future<void> _reaccionar(Map<String, dynamic> m, String emoji) async {
    setState(() => m['reaccion'] = emoji.isEmpty ? null : emoji);
    try { await api.reaccionar(m['id'] as int, emoji); }
    catch (e) { _err(e.toString().replaceFirst('Exception: ', '')); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: waBg,
      appBar: AppBar(
        backgroundColor: waGreen,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Text(_ini(widget.nombre), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(widget.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (_telefono != null) Text(_telefono!, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ])),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(8, 10, 8, 10), itemCount: _msgs.length,
                  itemBuilder: (_, i) => _burbuja(_msgs[i] as Map<String, dynamic>)),
        ),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(icon: const Icon(Icons.add, color: Colors.black54), onPressed: _enviando ? null : _menuAdjuntar),
                Expanded(child: TextField(
                  controller: _input, minLines: 1, maxLines: 5,
                  decoration: const InputDecoration(hintText: 'Mensaje', border: InputBorder.none, isDense: true),
                )),
                IconButton(icon: const Icon(Icons.photo_camera, color: Colors.black54), onPressed: _enviando ? null : () => _foto(ImageSource.camera)),
              ]),
            )),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _enviando ? null : _enviar,
              child: CircleAvatar(radius: 24, backgroundColor: waTeal,
                child: _enviando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_hayTexto ? Icons.send : Icons.mic, color: Colors.white)),
            ),
          ]),
        )),
      ]),
    );
  }

  String _ini(String n) {
    final p = n.trim().split(' ').where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'C';
    return (p.length == 1 ? p[0].substring(0, 1) : p[0].substring(0, 1) + p[1].substring(0, 1)).toUpperCase();
  }

  Widget _burbuja(Map<String, dynamic> m) {
    final mio = m['mio'] == true;
    final tipo = (m['tipo'] ?? 'text').toString();
    final media = m['media_url']?.toString();
    final texto = (m['contenido'] ?? '').toString();
    final hora = _hora(m['at']);

    Widget cuerpo;
    if (media != null && media.isNotEmpty && tipo == 'image') {
      cuerpo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: GestureDetector(
          onTap: () => _abrir(media),
          child: Image.network(media, width: 230, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(width: 230, height: 130, child: Icon(Icons.broken_image))),
        )),
        if (texto.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(texto, style: const TextStyle(fontSize: 14.5))),
      ]);
    } else if (media != null && media.isNotEmpty) {
      cuerpo = InkWell(onTap: () => _abrir(media), child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(tipo == 'audio' ? Icons.play_circle_fill : Icons.insert_drive_file, color: waTeal, size: 30),
        const SizedBox(width: 8),
        Flexible(child: Text(texto.isNotEmpty ? texto : (tipo == 'audio' ? 'Audio' : 'Documento'),
          style: const TextStyle(decoration: TextDecoration.underline))),
      ]));
    } else {
      cuerpo = Text(texto, style: const TextStyle(fontSize: 15, color: Color(0xFF111B21)));
    }

    final reaccion = m['reaccion']?.toString();

    final bubble = Container(
      margin: const EdgeInsets.only(top: 2, left: 2, right: 2),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
      decoration: BoxDecoration(
        color: mio ? waBubbleOut : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(10),
          topRight: const Radius.circular(10),
          bottomLeft: Radius.circular(mio ? 10 : 2),
          bottomRight: Radius.circular(mio ? 2 : 10),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 1, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        cuerpo,
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(hora, style: const TextStyle(fontSize: 10.5, color: Colors.black45)),
          if (mio) ...[
            const SizedBox(width: 3),
            const Icon(Icons.done_all, size: 14, color: Color(0xFF53BDEB)),
          ],
        ]),
      ]),
    );

    return GestureDetector(
      onLongPress: () => _menuReaccion(m),
      child: Align(
        alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: (reaccion != null && reaccion.isNotEmpty) ? 12 : 0),
          child: Stack(clipBehavior: Clip.none, children: [
            bubble,
            if (reaccion != null && reaccion.isNotEmpty)
              Positioned(
                bottom: -10, right: mio ? 8 : null, left: mio ? null : 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 2)]),
                  child: Text(reaccion, style: const TextStyle(fontSize: 14)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
