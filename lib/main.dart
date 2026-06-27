import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/pedidos_screen.dart';

void main() => runApp(const KivoxApp());

// Color de marca Kivox
const kBrand = Color(0xFF7C3AED);

class KivoxApp extends StatelessWidget {
  const KivoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kivox Repartidores',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBrand,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBrand,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const _Arranque(),
    );
  }
}

/// Decide la pantalla inicial: si ya hay token guardado, va a Pedidos.
class _Arranque extends StatefulWidget {
  const _Arranque();
  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  bool _cargando = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token != null && _token!.isNotEmpty) {
      return PedidosScreen(token: _token!);
    }
    return const LoginScreen();
  }
}
