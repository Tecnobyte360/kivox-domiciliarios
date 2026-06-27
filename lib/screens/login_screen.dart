import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../main.dart';
import 'pedidos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ctrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  Future<void> _entrar() async {
    final token = _ctrl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Pega tu código de acceso.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await KivoxApi.login(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PedidosScreen(token: token)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: kBrand,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.motorcycle, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 20),
                const Text('Kivox Repartidores',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Ingresa con tu código de acceso',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 28),
                TextField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    labelText: 'Código de acceso',
                    hintText: 'Pega aquí tu código',
                    prefixIcon: const Icon(Icons.key),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _cargando ? null : _entrar,
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _cargando
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tu código es el que aparece al final del enlace que te envió el negocio (…/d/TU-CODIGO).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
