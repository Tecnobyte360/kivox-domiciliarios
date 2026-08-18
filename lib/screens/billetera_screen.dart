import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../main.dart';

/// 💰 Billetera de efectivo del domiciliario: saldo, tope, días con efectivo,
///    desglose por aliado y devolución (con foto de evidencia).
class BilleteraScreen extends StatefulWidget {
  final String token;
  const BilleteraScreen({super.key, required this.token});
  @override
  State<BilleteraScreen> createState() => _BilleteraScreenState();
}

class _BilleteraScreenState extends State<BilleteraScreen> {
  late final KivoxApi api = KivoxApi(widget.token);
  bool _cargando = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final d = await api.billetera();
      if (mounted) setState(() { _data = d; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  double get _saldo => (_data['saldo'] ?? 0).toDouble();
  double get _tope => (_data['tope'] ?? 200).toDouble();
  String get _moneda => (_data['moneda'] ?? 'USD').toString();
  int get _dias => (_data['dias'] ?? 0) as int;
  bool get _bloqueado => (_data['bloqueado'] ?? false) as bool;
  List get _porAliado => (_data['por_aliado'] ?? []) as List;

  String _money(num v) => '${v.toStringAsFixed(2)} $_moneda';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi billetera')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _tarjetaSaldo(),
                      const SizedBox(height: 16),
                      if (_porAliado.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('No tienes efectivo pendiente 🎉', style: TextStyle(color: Colors.black54))),
                        )
                      else ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Efectivo por aliado', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        ),
                        ..._porAliado.map(_filaAliado),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off, size: 40, color: Colors.black26),
          const SizedBox(height: 8),
          const Text('No se pudo cargar la billetera'),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ]),
      );

  Widget _tarjetaSaldo() {
    final pct = _tope > 0 ? (_saldo / _tope).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kBrand, kBrandDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Efectivo que llevas', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(_money(_saldo), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.white24, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('Tope ${_money(_tope)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          if (_dias > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text('$_dias días', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ]),
        if (_bloqueado) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.lock, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Llevas mucho tiempo con efectivo. Devuélvelo para volver a recibir pedidos con efectivo.',
                  style: TextStyle(color: Colors.white, fontSize: 12))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _filaAliado(dynamic a) {
    final nombre = (a['nombre'] ?? 'Aliado').toString();
    final monto = (a['monto'] ?? 0).toDouble();
    final aliadoId = (a['aliado_id'] ?? 0) as int;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: kBrand.withOpacity(.15), child: const Icon(Icons.store, color: kBrand)),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Debes devolver ${_money(monto)}'),
        trailing: ElevatedButton.icon(
          onPressed: () => _abrirDevolucion(aliadoId, nombre, monto),
          icon: const Icon(Icons.upload, size: 16),
          label: const Text('Devolver'),
          style: ElevatedButton.styleFrom(backgroundColor: kBrand, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
        ),
      ),
    );
  }

  void _abrirDevolucion(int aliadoId, String nombre, double maximo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DevolucionSheet(
        api: api, aliadoId: aliadoId, nombre: nombre, maximo: maximo, moneda: _moneda,
        onDone: () { Navigator.pop(context); _cargar(); },
      ),
    );
  }
}

/// Hoja de devolución: monto + foto obligatoria.
class _DevolucionSheet extends StatefulWidget {
  final KivoxApi api;
  final int aliadoId;
  final String nombre;
  final double maximo;
  final String moneda;
  final VoidCallback onDone;
  const _DevolucionSheet({required this.api, required this.aliadoId, required this.nombre, required this.maximo, required this.moneda, required this.onDone});
  @override
  State<_DevolucionSheet> createState() => _DevolucionSheetState();
}

class _DevolucionSheetState extends State<_DevolucionSheet> {
  final _montoCtrl = TextEditingController();
  String? _fotoDataUrl;
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _montoCtrl.text = widget.maximo.toStringAsFixed(2);
  }

  Future<void> _tomarFoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1400);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() => _fotoDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    } catch (e) {
      setState(() => _error = 'No se pudo tomar la foto.');
    }
  }

  Future<void> _enviar() async {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    if (monto <= 0) { setState(() => _error = 'Escribe el monto.'); return; }
    if (monto > widget.maximo + 0.001) { setState(() => _error = 'Máximo ${widget.maximo.toStringAsFixed(2)} ${widget.moneda}.'); return; }
    if (_fotoDataUrl == null) { setState(() => _error = 'Toma la foto del efectivo entregado.'); return; }
    setState(() { _enviando = true; _error = null; });
    try {
      await widget.api.registrarDevolucion(aliadoId: widget.aliadoId, monto: monto, foto: _fotoDataUrl!);
      if (mounted) widget.onDone();
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _enviando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Devolver a ${widget.nombre}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Llevas ${widget.maximo.toStringAsFixed(2)} ${widget.moneda} de este aliado', style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Monto a devolver (${widget.moneda})', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.attach_money)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _enviando ? null : _tomarFoto,
            icon: Icon(_fotoDataUrl == null ? Icons.photo_camera : Icons.check_circle, color: _fotoDataUrl == null ? Colors.black54 : kBrand),
            label: Text(_fotoDataUrl == null ? 'Tomar foto del efectivo' : 'Foto lista ✓'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _enviando ? null : _enviar,
            style: ElevatedButton.styleFrom(backgroundColor: kBrand, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
            child: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Enviar devolución', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          const Text('El aliado confirmará la recepción. Hasta entonces sigue en tu saldo.', style: TextStyle(color: Colors.black45, fontSize: 11)),
        ]),
      ),
    );
  }
}
