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
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  bool _verPass = false;
  String? _error;

  Future<void> _entrar() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Escribe tu usuario y tu clave.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await KivoxApi.login(email, pass);
      final token = (data['token'] ?? '').toString();
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
                Image.asset('assets/logo.png', width: 150, height: 150),
                const Text('Repartidores',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kBrand)),
                const SizedBox(height: 6),
                const Text('Inicia sesión con tu usuario y clave',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Usuario (correo)',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passCtrl,
                  obscureText: !_verPass,
                  onSubmitted: (_) => _entrar(),
                  decoration: InputDecoration(
                    labelText: 'Clave',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _verPass = !_verPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
